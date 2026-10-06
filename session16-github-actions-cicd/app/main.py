"""Calculator web API used for the Session 16 CI/CD demo."""
import os

from flask import Flask, jsonify, request

from app.calculator import OPERATIONS

app = Flask(__name__)
APP_VERSION = os.environ.get("APP_VERSION", "dev")


@app.get("/")
def index():
    return (
        "<html><head><title>Session 16 CI/CD Calculator</title></head>"
        "<body style='font-family:sans-serif;text-align:center;padding-top:60px'>"
        "<h1>Calculator API - deployed by GitHub Actions CD pipeline</h1>"
        f"<h2>Version: {APP_VERSION}</h2>"
        "<p>Try <code>/api/add?a=10&amp;b=5</code> or <code>/health</code></p>"
        "<p>Poorav Kumar Gupta (24bcs10080)</p></body></html>"
    )


@app.get("/health")
def health():
    return jsonify(status="ok", version=APP_VERSION)


@app.get("/api/<op>")
def calculate(op):
    if op not in OPERATIONS:
        return jsonify(error=f"unknown operation '{op}'"), 404
    try:
        a = float(request.args["a"])
        b = float(request.args["b"])
        return jsonify(operation=op, a=a, b=b, result=OPERATIONS[op](a, b))
    except (KeyError, ValueError) as exc:
        return jsonify(error=str(exc)), 400


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=int(os.environ.get("PORT", "5000")))  # nosec B104 - container
