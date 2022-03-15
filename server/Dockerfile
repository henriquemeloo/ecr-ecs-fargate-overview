FROM python:3.9-slim

RUN pip install flask==2.0.2 boto3==1.15.18

COPY app.py .

ENTRYPOINT [ "python", "-m", "flask", "run", "--host=0.0.0.0", "--port=80" ]
