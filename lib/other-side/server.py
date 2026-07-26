#!/usr/bin/env python3
import threading
import time
import sys
import json
import re
import os
import atexit
import signal
from datetime import datetime
from typing import Optional, Protocol, Any
from flask import Flask, request, jsonify
from netmiko import ConnectHandler

# -------------------- Defaults --------------------
DEFAULT_ENABLE_PASSWORD = "cisco"
DEFAULT_SSH_USERNAME = "class"
DEFAULT_SSH_PASSWORD = "Passw.rd"

app = Flask(__name__)
HOST = "0.0.0.0"
PORT = 8081

MANAGER: Any = None

# -------------------- Logging --------------------
def log_event(event: str, **fields):
    """Log an event to console."""
    ts = datetime.utcnow().isoformat() + "Z"
    print(f"[{ts}] {event}: {fields}")

def log_rx(device: str, data: str):
    """Log received data (simplified)."""
    # In a server context, we might not want to spam stdout with all RX data
    # unless debugging.
    # print(f"[RX] {device}: {data}")
    pass

# -------------------- Device Logic --------------------

class DeviceSession(Protocol):
    def send(self, data: str) -> None: ...
    def start(self) -> None: ...
    def get_recent_rx(self) -> str: ...
    def clear_recent_rx(self) -> None: ...
    def close(self) -> None: ...
    def execute_command(self, cmd: str) -> str: ...

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
            log_event("connect_error", device=self.device_id, error=str(e))
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
                        log_rx(self.device_id, out)
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
    Configures the device with standard settings.
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
        self.sessions: list[tuple[str, DeviceSession]] = []
        self._by_key: dict[str, DeviceSession] = {}

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

# -------------------- Helpers --------------------

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

def _get_session(target, username, password, secret):
    global MANAGER
    if re.match(r"^COM\d+$", target, re.IGNORECASE):
        return MANAGER.get_or_add_serial(target)
    else:
        host = target
        # Check if target is an IP or needs conversion
        if re.match(r"^\d+$", target) or (re.match(r"^[\d\.]+$", target) and target.count('.') < 3):
             host = _device_id_to_ip(target)
        
        return MANAGER.get_or_add_ssh(host, username, password, secret=secret)

# -------------------- Routes --------------------

@app.route('/command', methods=['POST'])
def route_command():
    data = request.get_json(force=True, silent=True)
    if not data:
        return jsonify({"error": "No JSON data"}), 400
    
    target = data.get("target") or data.get("device")
    command = data.get("command")
    
    if not target or not command:
        return jsonify({"error": "Missing target or command"}), 400

    username = data.get("username", DEFAULT_SSH_USERNAME)
    password = data.get("password", DEFAULT_SSH_PASSWORD)
    enable_pw = data.get("enable_password", DEFAULT_ENABLE_PASSWORD)

    try:
        session = _get_session(target, username, password, enable_pw)
        output = ""
        if hasattr(session, "execute_command"):
            output = str(session.execute_command(command))
        else:
            session.send(command)
            output = "Command sent (async)"
        
        return jsonify({"status": "ok", "output": output})
    except Exception as e:
        return jsonify({"status": "error", "error": str(e)}), 500

@app.route('/setup', methods=['POST'])
def route_setup():
    data = request.get_json(force=True, silent=True)
    if not data:
        return jsonify({"error": "No JSON data"}), 400
    
    target = data.get("target") or data.get("device")
    device_id = data.get("device_id")
    
    if not target:
        return jsonify({"error": "Missing target"}), 400

    username = data.get("username", DEFAULT_SSH_USERNAME)
    password = data.get("password", DEFAULT_SSH_PASSWORD)
    enable_pw = data.get("enable_password", DEFAULT_ENABLE_PASSWORD)

    try:
        session = _get_session(target, username, password, enable_pw)
        
        # Determine ID if not provided
        if not device_id:
            m = re.search(r"(\d+)", target)
            if m:
                device_id = int(m.group(1))
            else:
                device_id = 0
        
        output = setup_device(session, int(device_id))
        return jsonify({"status": "ok", "output": output})
    except Exception as e:
        return jsonify({"status": "error", "error": str(e)}), 500

@app.route('/', defaults={'path': ''}, methods=['GET', 'POST'])
@app.route('/<path:path>', methods=['GET', 'POST'])
def handle_request(path):
    # Keep existing echo behavior for unknown paths or root
    if path == "" or path == "echo":
        path_to_log = request.full_path if request.query_string else request.path
        if request.method == 'GET':
            print(f"[GET] {path_to_log} from {request.remote_addr}")
            response = {"status": "ok", "method": "GET", "path": path_to_log}
            return jsonify(response)
        elif request.method == 'POST':
            body = request.get_data(as_text=True)
            print(f"[POST] {path_to_log} from {request.remote_addr}")
            response = {"status": "ok", "method": "POST", "received": body}
            return jsonify(response)
    return jsonify({"status": "error", "message": "Not found"}), 404

def main():
    global MANAGER
    MANAGER = MultiDeviceManager()
    
    # Register cleanup
    atexit.register(MANAGER.close_all)
    
    # Handle signals
    def _shutdown_handler(signum=None, frame=None):
        if MANAGER:
            MANAGER.close_all()
        sys.exit(0)

    signal.signal(signal.SIGINT, _shutdown_handler)
    signal.signal(signal.SIGTERM, _shutdown_handler)

    print(f"[HTTP] Server listening on {HOST}:{PORT}")
    app.run(host=HOST, port=PORT)

if __name__ == "__main__":
    main()
