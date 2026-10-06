import platform
import socket

from flask import Flask, jsonify

app = Flask(__name__)


@app.route("/")
def index():
    return f"<h1>Hello from Python Flask (multi-stage) - Session 07</h1><p>Container hostname: {socket.gethostname()}</p>"


@app.route("/health")
def health():
    return jsonify(status="ok", runtime="python", version=platform.python_version())
