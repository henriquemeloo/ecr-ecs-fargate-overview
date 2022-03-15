import os

from flask import Flask, request
import boto3


app = Flask(__name__)


@app.route("/")
def home():
    return ("<h1>ecr-ecs-fargate-overview</h1>", 200)


@app.route("/health")
def health():
    return ("I'm alive", 200)


@app.route("/run")
def run():
    ecs = boto3.client("ecs")
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
    return (response["tasks"][0]["taskArn"].split(":task/")[-1], 200)


@app.route("/status")
def status():
    ecs = boto3.client("ecs")
    task_description = ecs.describe_tasks(
        cluster=os.environ.get("CLUSTER_NAME"),
        tasks=[request.args.get("id")]
    )
    task_status = task_description["tasks"][0]["lastStatus"]
    return (task_status, 200)


if __name__ == "__main__":
    app.run(port="8080", debug=True)
