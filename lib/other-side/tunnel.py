import subprocess
import threading
import time

def keep_tunnel_alive():
    while True:
        proc = subprocess.Popen([
            "ssh",
            "-N",                # no shell
            "-R", "5022:localhost:22",
            "-R", "8080:127.0.0.1:8080",
            "-R", "8081:127.0.0.1:8081",
            "-R", "8082:127.0.0.1:8082",
            "Admin@cd-gulf.gl.at.ply.gg",
            "-p", "20430",
            "-o", "ServerAliveInterval=30",
            "-o", "ServerAliveCountMax=3",
            "-o", "ExitOnForwardFailure=yes"
        ])
        proc.wait()
        print("[TUNNEL] Tunnel process exited, restarting...")
        time.sleep(5)    # avoid hot loop if server is unreachable


def start_tunnel_thread():
    t = threading.Thread(
        target=keep_tunnel_alive,
        daemon=True
    )
    t.start()
    print("[TUNNEL] Reverse tunnel thread started")

if __name__ == "__main__":
    start_tunnel_thread()
    while True:
        time.sleep(60)  # Keep main thread alive