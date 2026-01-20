import websocket
import threading
import time
import sys
import json
import re
import os
import atexit
import signal
from datetime import datetime
from typing import Optional, Protocol, Any  # added Protocol
from netmiko import ConnectHandler

# -------------------- Defaults --------------------
WS_URL = os.getenv("KTRACER_WS_URL", "ws://along-translator.gl.at.ply.gg:47799/ws") # asuzdg; env override allowed
DEFAULT_ENABLE_PASSWORD = "cisco"       # Used for enable on serial or SSH when needed
DEFAULT_SSH_USERNAME = "class"
DEFAULT_SSH_PASSWORD = "Passw.rd"

MANAGER: Any = None  # Will be set in __main__

# Active WebSocket reference for sending logs upstream
_ACTIVE_WS_APP: Optional[websocket.WebSocketApp] = None
_WS_SEND_LOCK = threading.Lock()

def ws_log(event: str, **fields):
    """Send a structured log event over the WebSocket, if connected.

    Payload example: {"type":"log","event":"rx","ts":"...","...":...}
    Silently no-ops if the WS isn't connected.
    """
    payload = {
        "type": "log",
        "event": event,
        "ts": datetime.utcnow().isoformat() + "Z",
    }
    payload.update(fields)
    data = json.dumps(payload, separators=(",", ":"))
    ws = _ACTIVE_WS_APP
    if ws is None:
        return
    try:
        with _WS_SEND_LOCK:
            ws.send(data)
    except Exception:
        # ignore send errors
        pass

def ws_log_rx(device: str, data: str, *, chunk_size: int = 2000) -> None:
    """Send all received device data upstream in chunks.

    - device: identifier like "serial:COM3" or "ssh:10.0.0.1"
    - data: full decoded text from the terminal processing layer
    - chunk_size: max characters per WS message (kept modest to avoid frame limits)
    """
    if not data:
        return
    try:
        total = len(data)
        frags = (total + chunk_size - 1) // chunk_size
        for i in range(frags):
            piece = data[i * chunk_size : (i + 1) * chunk_size]
            # Include simple fragmentation metadata for ordering/debug
            ws_log(
                "rx",
                device=device,
                data=piece,
                snippet=piece[-200:],
                frag=i + 1,
                frags=frags,
                total_len=total,
            )
    except Exception:
        # Never let logging failures impact device loops
        pass

# Define a common session protocol for static typing
class DeviceSession(Protocol):
    def send(self, data: str) -> None: ...
    def start(self) -> None: ...
    def get_recent_rx(self) -> str: ...
    def clear_recent_rx(self) -> None: ...
    def close(self) -> None: ...
    def execute_command(self, cmd: str) -> str: ...


# Sanitization and pager/initial-config handling are implemented in CiscoTerminal


def send_cmd(session: "DeviceSession", device: str, cmd: str, *, sensitive: bool = False) -> None:
    """Send a command to a device and log a structured TX event.

    Passwords or other secrets should set sensitive=True to avoid logging content.
    """
    # Skip empty or comment-only commands
    raw = (cmd or "").strip()
    if not raw:
        return
    if raw.startswith("#") or raw.startswith("!") or raw.startswith("//"):
        return
    try:
        display = "<redacted>" if sensitive else cmd
        ws_log("tx", device=device, command=display)
    except Exception:
        pass
    try:
        session.send(cmd)
    except Exception as e:
        try:
            ws_log("tx_error", device=device, error=str(e))
        except Exception:
            pass
        raise

# -------------------- WebSocket --------------------

def _device_to_target(payload: dict) -> str:
    """Return (mode, target). mode in {serial, ssh}. target is COMx or host.
    If payload["device"] looks like COM*, use serial.
    If it's numeric, use SSH and map to 192.168.x.y or 192.168.88.x from device_id/device.
    """
    dev = str(payload.get("device", "")).strip()
    dev_id = str(payload.get("device_id", "")).strip() or dev
    if re.match(r"^COM\d+$", dev, re.IGNORECASE):
        return dev.upper()
    # Otherwise assume SSH
    # Build host from dev_id if not explicitly provided
    host = payload.get("host") or _device_id_to_ip(dev_id)
    return host


def _device_id_to_ip(dev_id: str) -> str:
    dev_id = dev_id.strip()
    if "." in dev_id:
        try:
            x, y = dev_id.split(".", 1)
            if y == None or y == "":
                return f"192.168.88.{int(x)}"
            return f"192.168.{int(x)}.{int(y)}"
        except Exception:
            pass
    try:
        n = int(dev_id)
        if 0 <= n <= 255:
            return f"192.168.88.{n}"
    except Exception:
        pass
    # Fallback default
    return "192.168.88.1"


# -------------------- WebSocket callbacks --------------------

def on_open(ws):
    global _ACTIVE_WS_APP
    _ACTIVE_WS_APP = ws
    print("WebSocket opened")
    ws_log("ws_open", message="connected")
    # Proactively send device list on connect
    # Device list will no longer be sent automatically on open.


def _handle_ws_json(payload: dict):
    global MANAGER
    if MANAGER is None:
        print("Manager not ready")
        return

    target = _device_to_target(payload)
    command = str(payload.get("command", "")).strip()
    action = str(payload.get("action", "")).strip().lower()
    request_id = payload.get("request_id")

    print("Target:", target, "Command:", command, "Action:", action)

    # Credentials overrides
    username = payload.get("username", DEFAULT_SSH_USERNAME)
    password = payload.get("password", DEFAULT_SSH_PASSWORD)
    enable_pw = payload.get("enable_password", DEFAULT_ENABLE_PASSWORD)

    # Special: list devices request
    if (command and command.lower() in ("devices", "list_devices")) or action in ("devices", "list_devices"):
        # send_devices_over_ws() # Removed
        return

    if action == "setup":
        device_label = target
        ws_log("setup_received", device=device_label)

        def _setup_task():
            try:
                print(f"Starting setup task for {target} (req={request_id})")
                session = None
                if re.match(r"^COM\d+$", target, re.IGNORECASE):
                    session = MANAGER.get_or_add_serial(target)
                else:
                    session = MANAGER.get_or_add_ssh(target, username, password, secret=enable_pw)
                
                # Determine ID
                d_id = payload.get("device_id")
                if not d_id:
                    # Try to parse from COMx
                    m = re.search(r"(\d+)", target)
                    if m:
                        d_id = int(m.group(1))
                    else:
                        d_id = 0
                
                output = setup_device(session, int(d_id))
                
                ws_log("setup_complete", device=device_label)
                print(f"Setup complete. Output length: {len(output)}")

                if request_id:
                    resp = {
                        "type": "log",
                        "event": "command_result",
                        "request_id": request_id,
                        "device": device_label,
                        "output": output,
                        "ts": datetime.utcnow().isoformat() + "Z"
                    }
                    data = json.dumps(resp, separators=(",", ":"))
                    ws = _ACTIVE_WS_APP
                    if ws:
                        with _WS_SEND_LOCK:
                            ws.send(data)
            except Exception as e:
                print(f"Error executing setup on {target}: {e}")
                ws_log("setup_error", device=device_label, error=str(e))
                if request_id:
                    resp = {
                        "type": "log",
                        "event": "command_result",
                        "request_id": request_id,
                        "device": device_label,
                        "error": str(e),
                        "ts": datetime.utcnow().isoformat() + "Z"
                    }
                    data = json.dumps(resp, separators=(",", ":"))
                    ws = _ACTIVE_WS_APP
                    if ws:
                        with _WS_SEND_LOCK:
                            ws.send(data)

        threading.Thread(target=_setup_task, daemon=True).start()
        return

    if not command:
        print("No command provided in WS payload")
        return

    device_label = target  # use raw COMx or host/IP for logging
    ws_log("command_received", device=device_label, command=command)
    
    def _exec_task():
        try:
            print(f"Starting execution task for {target} (req={request_id})")
            session = None
            if re.match(r"^COM\d+$", target, re.IGNORECASE):
                session = MANAGER.get_or_add_serial(target)
            else:
                session = MANAGER.get_or_add_ssh(target, username, password, secret=enable_pw)
            
            output = ""
            if hasattr(session, "execute_command"):
                output = str(session.execute_command(command))
            else:
                session.send(command)
                print("Session does not support execute_command, sent async.")
            
            ws_log("command_complete", device=device_label)
            print(f"Command complete. Output length: {len(output)}")

            if request_id:
                resp = {
                    "type": "log",
                    "event": "command_result",
                    "request_id": request_id,
                    "device": device_label,
                    "output": output,
                    "ts": datetime.utcnow().isoformat() + "Z"
                }
                data = json.dumps(resp, separators=(",", ":"))
                ws = _ACTIVE_WS_APP
                if ws:
                    with _WS_SEND_LOCK:
                        ws.send(data)
                    print(f"Sent command_result for {request_id}")
                else:
                    print("WS not active, cannot send result")

        except Exception as e:
            print(f"Error executing command on {target}: {e}")
            ws_log("command_error", device=device_label, error=str(e))
            if request_id:
                resp = {
                    "type": "log",
                    "event": "command_result",
                    "request_id": request_id,
                    "device": device_label,
                    "error": str(e),
                    "ts": datetime.utcnow().isoformat() + "Z"
                }
                data = json.dumps(resp, separators=(",", ":"))
                ws = _ACTIVE_WS_APP
                if ws:
                    with _WS_SEND_LOCK:
                        ws.send(data)

    threading.Thread(target=_exec_task, daemon=True).start()


def on_message(ws, message):
    # Expect JSON, otherwise just print
    try:
        payload = json.loads(message)
        # Minimal debug (can be noisy):
        # ws_log("rx_ws", snippet=str(payload)[:200])
        if isinstance(payload, dict):
            # If it's a command payload
            if ("device" in payload or "command" in payload or "action" in payload):
                print(f"[_handle_ws_json] {payload}")
                _handle_ws_json(payload)
                return
            # If it's a devices request from server
            event = str(payload.get("event", "")).lower()
            if event == "devices_request":
                # Devices request handling removed
                return
    except Exception:
        pass
    print(message)


def on_error(ws, error):
    print(f"Error: {error}")
    ws_log("ws_error", error=str(error))


def on_close(ws, close_status_code, close_msg):
    global _ACTIVE_WS_APP
    print(f"WebSocket closed: code={close_status_code} msg={close_msg}")
    ws_log("ws_close", code=close_status_code, message=str(close_msg))
    if _ACTIVE_WS_APP is ws:
        _ACTIVE_WS_APP = None

class NetmikoSession:
    def __init__(self, connection_params: dict, device_id: str):
        self.device_id = device_id
        self.connection_params = connection_params
        self.net_connect = None
        self.rx_buffer = ""
        self.rx_lock = threading.Lock()
        self.command_lock = threading.Lock()
        self.running = False
        self.thread = None

    def start(self):
        if self.running:
            return
        try:
            self.net_connect = ConnectHandler(**self.connection_params)
            self.running = True
            self.thread = threading.Thread(target=self._read_loop, daemon=True)
            self.thread.start()
        except Exception as e:
            print(f"Failed to connect to {self.device_id}: {e}")
            ws_log("connect_error", device=self.device_id, error=str(e))
            raise

    def _read_loop(self):
        while self.running and self.net_connect:
            try:
                if self.command_lock.acquire(timeout=0.1):
                    try:
                        out = self.net_connect.read_channel()
                    finally:
                        self.command_lock.release()
                    
                    if out:
                        with self.rx_lock:
                            self.rx_buffer += out
                        ws_log_rx(self.device_id, out)
                    else:
                        time.sleep(0.1)
                else:
                    time.sleep(0.1)
            except Exception:
                break

    def send(self, data: str) -> None:
        if self.net_connect:
            with self.command_lock:
                self.net_connect.write_channel(data)

    def execute_command(self, cmd: str) -> str:
        if not self.net_connect:
            print(f"[{self.device_id}] Netmiko not connected, cannot execute command")
            return ""
        print(f"[{self.device_id}] Acquiring command lock for '{cmd}'...")
        with self.command_lock:
            print(f"[{self.device_id}] Sending command via netmiko...")
            try:
                res = self.net_connect.send_command(cmd)
                print(f"[{self.device_id}] Netmiko send_command returned {len(str(res))} chars.")
                return str(res)
            except Exception as e:
                print(f"[{self.device_id}] Netmiko send_command failed: {e}")
                raise

    def get_recent_rx(self) -> str:
        with self.rx_lock:
            return self.rx_buffer

    def clear_recent_rx(self) -> None:
        with self.rx_lock:
            self.rx_buffer = ""

    def close(self) -> None:
        self.running = False
        if self.net_connect:
            try:
                self.net_connect.disconnect()
            except Exception:
                pass
            self.net_connect = None


def setup_device(session: NetmikoSession, device_id: int) -> str:
    """
    Configures the device with standard settings:
    - Hostname (R{id}, S{id}, L3{id})
    - Domain kando.local
    - SSH setup (user class, key 1024, v2)
    - VLAN 88 (Management) with IP 192.168.88.{id}
    """
    if not session.net_connect:
        return "Error: Session not connected."

    try:
        device_id = int(device_id)
    except ValueError:
        return "Error: Invalid device ID"

    with session.command_lock:
        nc = session.net_connect
        
        # Ensure enable mode
        if not nc.check_enable_mode():
            nc.enable()

        # 1. Determine device type for hostname
        sh_ver = str(nc.send_command("show version"))
        
        hostname_prefix = "R" # Default
        
        # Heuristics for device type
        if any(m in sh_ver for m in ["C3560", "C3750", "C3650", "C3850", "C9300"]):
            hostname_prefix = "L3"
        elif any(m in sh_ver for m in ["C2960", "C2950", "C1000", "C9200", "Switch", "Catalyst"]):
            hostname_prefix = "S"
        
        hostname = f"{hostname_prefix}{device_id}"
        
        # 2. Prepare config
        cmds = [
            f"hostname {hostname}",
            "ip domain-name kando.local",
            "ip ssh version 2",
            "username class privilege 15 secret Passw.rd",

            "line vty 0 4",
            "transport input ssh",
            "login local",

            "vlan 88",
            "name Management",
            "exit",

            "interface vlan 88",
            f"ip address 192.168.88.{device_id} 255.255.255.0",
            "no shutdown",
            "exit",

            "interface fa0/24",
            "switchport mode access",
            "switchport access vlan 88",
            "spanning-tree portfast",
            "exit",

            "interface range g0/1-2",
            "switchport mode trunk",
            "exit"
        ]
        
        output = str(nc.send_config_set(cmds))
        
        # 3. Handle RSA key generation (interactive)
        try:
            # Use interactive command to handle various IOS versions/states
            out_crypto = str(nc.send_command_timing("crypto key generate rsa"))
            
            # If keys exist, it asks to replace
            if "replace" in out_crypto.lower():
                out_crypto += str(nc.send_command_timing("yes"))
            
            # If it asks for modulus size (which it should if we didn't specify it)
            if "bits in the modulus" in out_crypto.lower():
                out_crypto += str(nc.send_command_timing("1024"))
                
            output += "\n" + out_crypto
        except Exception as e:
            output += f"\nCrypto key generation failed: {e}"

        return output


class MultiDeviceManager:
    def __init__(self):
        self.sessions: list[tuple[str, DeviceSession]] = []            # typed to DeviceSession
        self._by_key: dict[str, DeviceSession] = {}                    # typed to DeviceSession

    def get_or_add_serial(self, port: str, baudrate: int = 9600, timeout: float = 1.0) -> DeviceSession:
        key = f"serial:{port}"
        if key in self._by_key:
            return self._by_key[key]
        
        params = {
            'device_type': 'cisco_ios_serial',
            'serial_settings': {
                'port': port,
                'baudrate': baudrate,
                'timeout': timeout
            }
        }
        session = NetmikoSession(params, key)
        session.start()
        self.sessions.append((key, session))
        self._by_key[key] = session
        return session

    def get_or_add_ssh(self, host: str, username: str, password: str, port: int = 22, secret: str = "") -> DeviceSession:
        key = f"ssh:{host}:{port}"
        if key in self._by_key:
            return self._by_key[key]

        params = {
            'device_type': 'cisco_ios',
            'host': host,
            'username': username,
            'password': password,
            'port': port,
            'secret': secret,
        }
        session = NetmikoSession(params, key)
        session.start()
        self.sessions.append((key, session))
        self._by_key[key] = session
        return session

    def broadcast(self, cmd: str):
        for name, s in self.sessions:
            try:
                s.send(cmd)
            except Exception as e:
                print(f"[{name}] send error: {e}")

    def close_all(self):
        for name, s in self.sessions:
            try:
                s.close()
            except Exception:
                pass


if __name__ == "__main__":
    # Example usage
    # 1) WebSocket client with auto-reconnect (start by default)
    def start_ws_forever():
        websocket.enableTrace(False)
        while True:
            try:
                ws_app = websocket.WebSocketApp(
                    WS_URL,
                    on_open=on_open,
                    on_message=on_message,
                    on_error=on_error,
                    on_close=on_close,
                )
                # Use built-in ping to keep connection alive; no custom ping thread needed
                ws_app.run_forever(ping_interval=20, ping_timeout=10)
            except Exception as e:
                print(f"WebSocket fatal error: {e}")
                try:
                    ws_log("ws_fatal", error=str(e))
                except Exception:
                    pass
            # Backoff before reconnecting
            time.sleep(3)
            print("Reconnecting WebSocket...")

    # 2) Multi-device manager
    MANAGER = MultiDeviceManager()

    # Install shutdown hooks to ensure ports/sessions are closed
    def _shutdown_handler(signum=None, frame=None):
        try:
            ws_log("shutdown_signal", signum=signum)
        except Exception:
            pass
        try:
            if MANAGER is not None:
                MANAGER.close_all()
        finally:
            # For SIGINT/SIGTERM, allow normal exit
            pass

    def _atexit_close_all():
        try:
            ws_log("shutdown_atexit")
        except Exception:
            pass
        try:
            if MANAGER is not None:
                MANAGER.close_all()
        except Exception:
            pass

    atexit.register(_atexit_close_all)
    # Register common signals (guard for platform availability)
    for _sig_name in ("SIGINT", "SIGTERM", "SIGBREAK"):
        _sig = getattr(signal, _sig_name, None)
        if _sig is not None:
            try:
                signal.signal(_sig, _shutdown_handler)
            except Exception:
                pass

    # Always start WS client in background (auto-reconnect)
    threading.Thread(target=start_ws_forever, daemon=True).start()

    # Parse simple CLI args for demo: python main-2.py serial:COM3 ssh:1.2.3.4,user,pass
    for arg in sys.argv[1:]:
        if arg == "ws":
            threading.Thread(target=start_ws_forever, daemon=True).start()

    print("Type commands to broadcast to all devices. Ctrl+C to exit.")
    try:
        while True:
            try:
                cmd = input("> ")
            except EOFError:
                time.sleep(0.2)
                continue
            except Exception as e:
                print(f"Input error: {e}")
                time.sleep(0.5)
                continue
            if not cmd:
                continue
            try:
                MANAGER.broadcast(cmd)
            except Exception as e:
                # Prevent any broadcast error from killing the process / WS
                print(f"Broadcast error: {e}")
    except KeyboardInterrupt:
        pass
    finally:
        MANAGER.close_all()