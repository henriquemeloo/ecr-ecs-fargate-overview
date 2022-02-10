import uuid

from flask import Flask, request


app = Flask(__name__)


@app.route("/health")
def health():
    return 200, "I'm alive"


@app.route("/run")
def run():
    return str(uuid.uuid4())

@app.route("/status")
def status():
    id_ = request.args.get("id")
    return f"running {id_}"


if __name__ == "__main__":
    app.run(port="80", debug=True)
