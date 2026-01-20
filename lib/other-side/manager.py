#!/usr/bin/env python3
import os
import subprocess
import threading
from flask import Flask, request, jsonify
from werkzeug.utils import secure_filename

app = Flask(__name__)

# Where uploaded scripts will be stored
UPLOAD_DIR = "apps"
os.makedirs(UPLOAD_DIR, exist_ok=True)

# Track running processes by "main" name
processes = {}
process_locks = threading.Lock()


def stream_logger(pipe, prefix):
    for line in iter(pipe.readline, ''):
        print(f"[{prefix}] {line}", end='')


def start_main(main_name):
    """Start a main script if not already running."""
    script_path = os.path.join(UPLOAD_DIR, main_name)

    if not os.path.isfile(script_path):
        return False, "Script does not exist"

    with process_locks:
        if main_name in processes and processes[main_name].poll() is None:
            return False, "Already running"

        proc = subprocess.Popen(
            ["python", script_path],
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            bufsize=1
        )

        threading.Thread(target=stream_logger, args=(proc.stdout, main_name), daemon=True).start()
        threading.Thread(target=stream_logger, args=(proc.stderr, main_name), daemon=True).start()

        processes[main_name] = proc

    return True, "Started"


def stop_main(main_name):
    """Stop a running main script."""
    with process_locks:
        if main_name not in processes:
            return False, "Not running"

        proc = processes[main_name]
        if proc.poll() is None:
            proc.terminate()
            try:
                proc.wait(timeout=5)
            except subprocess.TimeoutExpired:
                proc.kill()

        del processes[main_name]
    return True, "Stopped"


def status_main(main_name):
    """Check status."""
    with process_locks:
        if main_name not in processes:
            return False, "Not running"

        proc = processes[main_name]
        alive = proc.poll() is None

    return alive, "Running" if alive else "Stopped"


# ------------------------
#        ENDPOINTS
# ------------------------

@app.route("/update", methods=["POST"])
def update():
    """
    Accept file upload + ?main=<name>
    Replace stored file, restart its process.
    """
    if "file" not in request.files:
        return jsonify(error="Missing file"), 400

    main_name = request.form.get("main")
    if not main_name:
        return jsonify(error="Missing 'main' parameter"), 400

    file = request.files["file"]
    filename = secure_filename(main_name)
    save_path = os.path.join(UPLOAD_DIR, filename)

    # Store file
    file.save(save_path)

    # Restart main
    stop_main(main_name)
    ok, msg = start_main(main_name)

    return jsonify(ok=ok, message=msg)


@app.route("/start", methods=["POST"])
def start():
    main_name = request.args.get("main")
    if not main_name:
        return jsonify(error="Missing main"), 400

    ok, msg = start_main(main_name)
    return jsonify(ok=ok, message=msg)


@app.route("/stop", methods=["POST"])
def stop():
    main_name = request.args.get("main")
    if not main_name:
        return jsonify(error="Missing main"), 400

    ok, msg = stop_main(main_name)
    return jsonify(ok=ok, message=msg)


@app.route("/status", methods=["GET"])
def status():
    main_name = request.args.get("main")
    if not main_name:
        return jsonify(error="Missing main"), 400

    running, msg = status_main(main_name)
    return jsonify(running=running, message=msg)


# ------------------------
#        MAIN
# ------------------------

if __name__ == "__main__":
    app.run("0.0.0.0", 8082)
