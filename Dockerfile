FROM python:3.10-alpine3.21

ENV SALT_VERSION=3006.10
ENV ALPINE_VERSION=3.21

# 构建依赖
RUN apk add --no-cache \
    gcc g++ make autoconf \
    libffi-dev openssl-dev \
    musl-dev zeromq-dev \
    dumb-init \
    libgit2 libgit2-dev \
    openssh

# 创建 salt 用户和必要目录
RUN addgroup -g 450 -S salt && adduser -s /bin/sh -SD -G salt salt && \
    mkdir -p /etc/pki /etc/salt/pki /etc/salt/minion.d/ /etc/salt/master.d /etc/salt/proxy.d /var/cache/salt /var/log/salt /var/run/salt && \
    chmod -R 2775 /etc/pki /etc/salt /var/cache/salt /var/log/salt /var/run/salt && \
    chgrp -R salt /etc/pki /etc/salt /var/cache/salt /var/log/salt /var/run/salt

# 先升级pip相关，避免arm64构建metadata失败
RUN pip3 install --no-cache-dir --upgrade pip setuptools wheel packaging

# 限制 cython 版本（salt 依赖）
RUN echo "cython<3" > /tmp/constraint.txt

# 安装 salt
RUN PIP_CONSTRAINT=/tmp/constraint.txt USE_STATIC_REQUIREMENTS=1 \
    pip3 install --no-build-isolation --no-cache-dir salt=="${SALT_VERSION}"

# 预生成证书
RUN su - salt -c 'salt-run salt.cmd tls.create_self_signed_cert'

ENTRYPOINT ["/usr/bin/dumb-init"]
CMD ["/usr/local/bin/saltinit"]

ADD saltinit.py /usr/local/bin/saltinit

EXPOSE 4505 4506 8000
VOLUME /etc/salt/pki/
