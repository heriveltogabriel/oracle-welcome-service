FROM docker.io/fnproject/python:3.11-dev

WORKDIR /function
ENV PIP_TARGET=/python

COPY requirements.txt .
RUN pip3 install --target /python --no-cache-dir -r requirements.txt

COPY func.py /function/

ENV PYTHONPATH=/python
ENTRYPOINT ["/python/bin/fdk", "/function/func.py", "handler"]
