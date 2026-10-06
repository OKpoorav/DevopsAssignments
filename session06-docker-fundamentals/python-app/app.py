from flask import Flask

app = Flask(__name__)


@app.route("/")
def hello():
    return "<h1>Hello World from Python (Flask) in Docker!</h1><p>Session 06 - Poorav Kumar Gupta (24bcs10080)</p>"


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)
