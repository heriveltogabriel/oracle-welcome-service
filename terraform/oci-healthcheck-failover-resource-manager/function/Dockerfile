FROM docker.io/library/python:3.11-slim

WORKDIR /function
ENV PIP_TARGET=/python

COPY requirements.txt .
RUN pip3 install --target /python --no-cache-dir -r requirements.txt

COPY func.py /function/

ENV PYTHONPATH=/python
ENTRYPOINT ["/python/bin/fdk", "/function/func.py", "handler"]
