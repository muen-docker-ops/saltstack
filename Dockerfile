FROM debian:12-slim

ENV DEBIAN_FRONTEND=noninteractive
ARG SALT_VERSION
ENV SALT_VERSION=${SALT_VERSION}

# ---------------------------------------
# Basic packages & dumb-init
# ---------------------------------------
RUN apt-get update && apt-get install -y --no-install-recommends \
      ca-certificates curl gnupg2 dumb-init python3 python3-pip netcat-openbsd \
    && rm -rf /var/lib/apt/lists/*

# ---------------------------------------
# Add Salt official key + salt.sources
# ---------------------------------------
RUN mkdir -p /etc/apt/keyrings && \
    curl -fsSL https://packages.broadcom.com/artifactory/api/security/keypair/SaltProjectKey/public \
        | tee /etc/apt/keyrings/salt-archive-keyring.pgp > /dev/null

RUN curl -fsSL https://github.com/saltstack/salt-install-guide/releases/latest/download/salt.sources \
        | tee /etc/apt/sources.list.d/salt.sources > /dev/null

# ---------------------------------------
# Pin SALT version
# ---------------------------------------
RUN echo "Package: salt-*\n\
Pin: version ${SALT_VERSION}*\n\
Pin-Priority: 1001" \
    > /etc/apt/preferences.d/salt-pin-1001

# ---------------------------------------
# Create user & dirs
# ---------------------------------------
RUN groupadd -g 450 salt || true && \
    useradd -u 450 -g salt -s /bin/bash -M salt || true && \
    mkdir -p /etc/salt/master.d /etc/salt/minion.d /etc/pki/tls/certs


# ---------------------------------------
# Install Salt packages
# ---------------------------------------
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        salt-master=${SALT_VERSION}* \
        salt-api=${SALT_VERSION}* \
        salt-ssh=${SALT_VERSION}* \
        salt-syndic=${SALT_VERSION}* \
    && rm -rf /var/lib/apt/lists/*

# ---------------------------------------
# Add saltinit.py
# ---------------------------------------
COPY saltinit.py /usr/local/bin/saltinit
RUN chmod +x /usr/local/bin/saltinit

# ---------------------------------------
# Ports
# ---------------------------------------
EXPOSE 4505 4506 8000

# ---------------------------------------
# ENTRYPOINT + CMD
# ---------------------------------------
ENTRYPOINT ["/usr/bin/dumb-init", "--"]
CMD ["/usr/local/bin/saltinit"]

# ---------------------------------------
# HEALTHCHECK
# ---------------------------------------
HEALTHCHECK --interval=30s --timeout=3s --start-period=15s --retries=3 \
  CMD nc -z 127.0.0.1 4505 && nc -z 127.0.0.1 8000 || exit 1
