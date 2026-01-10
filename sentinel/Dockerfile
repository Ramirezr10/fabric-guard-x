FROM python:3.9-slim

RUN apt-get update && apt-get install -y iproute2 iputils-ping curl

RUN pip install prometheus_client

# This is our "Version Marker"
RUN touch /etc/is_v4_sentinel

COPY sentinel.py /sentinel/sentinel.py
WORKDIR /sentinel

CMD ["python", "sentinel.py"]