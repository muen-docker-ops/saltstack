FROM debian:12.10

RUN apt update && \
apt-get install -y openssh-server curl && pip install salt=3006.10
