#!/usr/bin/env python3
import asyncio
import json
import os
import signal
import pathlib
import subprocess


CERT_DIR = pathlib.Path("/etc/pki/tls/certs")
KEY_PATH = CERT_DIR / "localhost.key"
CRT_PATH = CERT_DIR / "localhost.crt"

SALT_UID = 450
SALT_GID = 450


def ensure_real_openssl_cert():
    """创建真正的 PEM 格式证书，避免 CherryPy PermissionError"""
    CERT_DIR.mkdir(parents=True, exist_ok=True)

    if KEY_PATH.exists() and CRT_PATH.exists():
        return

    print("Generating REAL openssl PEM certificate...")

    subprocess.run([
        "openssl", "req",
        "-x509",
        "-newkey", "rsa:2048",
        "-nodes",
        "-keyout", str(KEY_PATH),
        "-out", str(CRT_PATH),
        "-days", "3650",
        "-subj", "/CN=localhost"
    ], check=True)

    os.chown(KEY_PATH, SALT_UID, SALT_GID)
    os.chmod(KEY_PATH, 0o600)

    os.chown(CRT_PATH, SALT_UID, SALT_GID)
    os.chmod(CRT_PATH, 0o600)


async def main():
    # 生成真正的 PEM 证书
    ensure_real_openssl_cert()

    futures = []

    # minion 模式
    if "SALT_MINION_CONFIG" in os.environ:
        with open("/etc/salt/minion.d/minion.conf", "w") as f:
            json.dump(json.loads(os.environ["SALT_MINION_CONFIG"]), f)
        futures.append(await asyncio.create_subprocess_exec("salt-minion"))

    # proxy 模式
    elif "SALT_PROXY_ID" in os.environ or "SALT_PROXY_CONFIG" in os.environ:
        if "SALT_PROXY_CONFIG" in os.environ:
            with open("/etc/salt/proxy.d/proxy.conf", "w") as f:
                json.dump(json.loads(os.environ["SALT_PROXY_CONFIG"]), f)
        if "SALT_PROXY_ID" in os.environ:
            futures.append(await asyncio.create_subprocess_exec(
                "salt-proxy",
                f'--proxyid={os.environ["SALT_PROXY_ID"]}'
            ))
        else:
            futures.append(await asyncio.create_subprocess_exec("salt-proxy"))

    # master + api 模式
    else:
        if not os.path.exists("/etc/salt/master.d/api.conf"):
            with open("/etc/salt/master.d/api.conf", "w") as f:
                json.dump({
                    "rest_cherrypy": {
                        "port": 8000,
                        "ssl_crt": str(CRT_PATH),
                        "ssl_key": str(KEY_PATH),
                    },
                    "external_auth": {
                        "sharedsecret": {
                            "salt": [".*", "@wheel", "@jobs", "@runner"],
                        }
                    },
                    "sharedsecret": os.environ.get("SALT_SHARED_SECRET", "supersecret")
                }, f)

        with open("/etc/salt/master.d/user.conf", "w") as f:
            json.dump({"user": "salt"}, f)

        futures.append(await asyncio.create_subprocess_exec("salt-api"))
        futures.append(await asyncio.create_subprocess_exec("salt-master"))

    await asyncio.gather(*[p.communicate() for p in futures])


if __name__ == "__main__":
    loop = asyncio.get_event_loop()
    for sig in ("SIGINT", "SIGTERM"):
        loop.add_signal_handler(getattr(signal, sig), loop.stop)
    try:
        loop.run_until_complete(main())
    finally:
        loop.close()
