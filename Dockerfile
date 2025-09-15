FROM python:3.10-alpine3.21

# 环境变量
ENV SALT_VERSION=3006.10
ENV ALPINE_VERSION=3.21
ENV TZ="Asia/Shanghai"

# 安装系统依赖
RUN apk add --no-cache \
    gcc g++ autoconf make \
    libffi-dev openssl-dev musl-dev zeromq-dev \
    dumb-init \
    libgit2 libgit2-dev \
    openssh tzdata

# 创建 salt 用户及目录
RUN addgroup -g 450 -S salt && \
    adduser -s /bin/sh -SD -G salt salt && \
    mkdir -p /etc/pki /etc/salt/pki \
             /etc/salt/minion.d /etc/salt/master.d /etc/salt/proxy.d \
             /var/cache/salt /var/log/salt /var/run/salt && \
    chmod -R 2775 /etc/pki /etc/salt /var/cache/salt /var/log/salt /var/run/salt && \
    chgrp -R salt /etc/pki /etc/salt /var/cache/salt /var/log/salt /var/run/salt

# 更新 pip 工具
RUN pip3 install --no-cache-dir --upgrade pip setuptools wheel packaging

# 限制 cython 版本
RUN echo "cython<3" > /tmp/constraint.txt

# 安装 msgpack，解决 salt 依赖
RUN pip3 install --no-cache-dir "yaml" && \
    pip3 install --no-cache-dir "msgpack==1.0.5"

# 安装 salt
RUN PIP_CONSTRAINT=/tmp/constraint.txt USE_STATIC_REQUIREMENTS=1 \
    pip3 install --no-build-isolation --no-cache-dir salt=="${SALT_VERSION}"

# 拷贝启动脚本
ADD saltinit.py /usr/local/bin/saltinit
RUN chmod +x /usr/local/bin/saltinit

# 设置容器启动
ENTRYPOINT ["/usr/bin/dumb-init"]
CMD ["/usr/local/bin/saltinit"]

# 端口 & 挂载
EXPOSE 4505 4506 8000
VOLUME /etc/salt/pki/
