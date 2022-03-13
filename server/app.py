import os

from flask import Flask, request
import boto3


app = Flask(__name__)

env = os.environ.get("STACK_ENV")


@app.route("/health")
def health():
    return (f"I'm alive, running env {env}", 200)


@app.route("/run")
def run():
    ecs = boto3.Client("ecs")
    response = ecs.run_task(
        cluster=os.environ.get("CLUSTER_NAME"),
        taskDefinition=os.environ.get("TASK_NAME"),
        networkConfiguration={
            "awsvpcConfiguration":{
                "subnets": [os.environ.get("SUBNET_ID")]
            }
        },
        launchType="FARGATE"
    )
    return (response["tasks"]["attachments"]["id"], 200)


@app.route("/status")
def status():
    id_ = request.args.get("id")
    return (f"running {id_}", 200)


if __name__ == "__main__":
    app.run(port="8080", debug=True)
