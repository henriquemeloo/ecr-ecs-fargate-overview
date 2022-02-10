FROM python:3.9-slim

RUN pip install flask==2.0.2

COPY api.py .

ENTRYPOINT [ "python", "api.py" ]
