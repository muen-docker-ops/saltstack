FROM python:3.10-bookworm

ENV SALT_VERSION=3006.10
ENV TZ="Asia/Shanghai"

RUN addgroup -g 450 -S salt && adduser -s /bin/sh -SD -G salt salt && \
    mkdir -p /etc/pki /etc/salt/pki /etc/salt/minion.d/ /etc/salt/master.d /etc/salt/proxy.d /var/cache/salt /var/log/salt /var/run/salt && \
    chmod -R 2775 /etc/pki /etc/salt /var/cache/salt /var/log/salt /var/run/salt && \
    chgrp -R salt /etc/pki /etc/salt /var/cache/salt /var/log/salt /var/run/salt

RUN echo "cython<3" > /tmp/constraint.txt
RUN PIP_CONSTRAINT=/tmp/constraint.txt USE_STATIC_REQUIREMENTS=1 pip3 install --no-build-isolation --no-cache-dir salt=="${SALT_VERSION}"
RUN su - salt -c 'salt-run salt.cmd tls.create_self_signed_cert'

# 拷贝启动脚本
ADD saltinit.py /usr/local/bin/saltinit

# 设置容器启动
ENTRYPOINT ["/usr/bin/dumb-init"]
CMD ["/usr/local/bin/saltinit"]

# 端口 & 挂载
EXPOSE 4505 4506 8000
VOLUME /etc/salt/pki/
