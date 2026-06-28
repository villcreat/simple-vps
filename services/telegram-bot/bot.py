"""VPS Simple Telegram bot — a simple, read-mostly alternative interface.

Per the spec this bot runs on its own VPS, gets the server list from the
app's encrypted export file, and grants access only to an allow-listed Telegram
ID *and* a password (never one without the other). It is intentionally not a
sync server and only offers safe, read-only actions (status, logs).

Config via environment variables:
  BOT_TOKEN             Telegram bot token
  BOT_PASSWORD          password required by /login
  ALLOWED_TELEGRAM_IDS  comma-separated numeric Telegram user ids
  EXPORT_FILE           path to the encrypted export file from the app
  EXPORT_PASSWORD       password that decrypts the export file
"""

import html
import os
import time
from io import StringIO

import paramiko
import requests

from vaultfile import decrypt_export

TOKEN = os.environ["BOT_TOKEN"]
BOT_PASSWORD = os.environ["BOT_PASSWORD"]
ALLOWED_IDS = {
    int(x)
    for x in os.environ.get("ALLOWED_TELEGRAM_IDS", "").replace(" ", "").split(",")
    if x
}
EXPORT_FILE = os.environ["EXPORT_FILE"]
EXPORT_PASSWORD = os.environ["EXPORT_PASSWORD"]

API = f"https://api.telegram.org/bot{TOKEN}"

# Telegram ids that have passed /login this session.
_authed: set[int] = set()


def send(chat_id: int, text: str) -> None:
    requests.post(
        f"{API}/sendMessage",
        json={"chat_id": chat_id, "text": text, "parse_mode": "HTML"},
        timeout=30,
    )


def _load_key(pem: str, passphrase):
    for cls in (
        paramiko.Ed25519Key,
        paramiko.ECDSAKey,
        paramiko.RSAKey,
        paramiko.DSSKey,
    ):
        try:
            return cls.from_private_key(StringIO(pem), password=passphrase or None)
        except Exception:  # noqa: BLE001 - try the next key type
            continue
    raise ValueError("Unsupported private key format")


def ssh_run(server: dict, secrets: dict, command: str, timeout: int = 20) -> str:
    cred = secrets.get(server.get("secretReference", ""), {})
    client = paramiko.SSHClient()
    # TODO: pin host keys instead of auto-adding (see app's open security item).
    client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    connect = {
        "hostname": server["host"],
        "port": server.get("sshPort", 22),
        "username": server["username"],
        "timeout": timeout,
    }
    if cred.get("type") == "key":
        connect["pkey"] = _load_key(cred.get("privateKeyPem", ""), cred.get("passphrase"))
    else:
        connect["password"] = cred.get("password", "")

    client.connect(**connect)
    try:
        _, stdout, stderr = client.exec_command(command, timeout=timeout)
        out = stdout.read().decode("utf-8", "replace")
        err = stderr.read().decode("utf-8", "replace")
        return (out + err).strip()
    finally:
        client.close()


def _require_auth(uid: int, chat_id: int) -> bool:
    if uid not in ALLOWED_IDS:
        send(chat_id, "Access denied.")
        return False
    if uid not in _authed:
        send(chat_id, "Send /login &lt;password&gt; first.")
        return False
    return True


def _server_index(text: str):
    parts = text.split()
    if len(parts) < 2:
        return None
    try:
        return int(parts[1]) - 1
    except ValueError:
        return None


def handle(update: dict) -> None:
    message = update.get("message") or {}
    chat_id = (message.get("chat") or {}).get("id")
    uid = (message.get("from") or {}).get("id")
    text = (message.get("text") or "").strip()
    if not chat_id or uid is None or not text:
        return

    # Hard gate: unknown ids never get past here.
    if uid not in ALLOWED_IDS:
        send(chat_id, "Access denied.")
        return

    if text.startswith("/login"):
        parts = text.split(maxsplit=1)
        if len(parts) == 2 and parts[1] == BOT_PASSWORD:
            _authed.add(uid)
            send(chat_id, "Logged in.")
        else:
            send(chat_id, "Wrong password.")
        return

    if text in ("/start", "/help"):
        send(
            chat_id,
            "VPS Simple bot.\n/login &lt;password&gt;\n/servers\n"
            "/status &lt;n&gt;\n/logs &lt;n&gt;",
        )
        return

    if not _require_auth(uid, chat_id):
        return

    try:
        payload = decrypt_export(EXPORT_FILE, EXPORT_PASSWORD)
    except Exception as error:  # noqa: BLE001
        send(chat_id, f"Cannot read server file: {error}")
        return
    servers = payload["servers"]
    secrets = payload["secrets"]

    if text == "/servers":
        if not servers:
            send(chat_id, "No servers.")
            return
        lines = [
            f"{i + 1}. {s.get('name')} ({s.get('username')}@{s.get('host')})"
            for i, s in enumerate(servers)
        ]
        send(chat_id, "\n".join(lines))
        return

    if text.startswith("/status") or text.startswith("/logs"):
        index = _server_index(text)
        if index is None or index < 0 or index >= len(servers):
            send(chat_id, "Usage: /status &lt;n&gt; (see /servers)")
            return
        server = servers[index]
        if text.startswith("/status"):
            command = "uname -a; uptime; df -h /; free -m"
        else:
            command = (
                "journalctl -n 30 --no-pager 2>/dev/null || tail -n 30 /var/log/syslog"
            )
        try:
            output = ssh_run(server, secrets, command)
        except Exception as error:  # noqa: BLE001
            send(chat_id, f"SSH error: {error}")
            return
        send(chat_id, "<pre>" + html.escape(output[:3500] or "(no output)") + "</pre>")
        return

    send(chat_id, "Unknown command. /help")


def main() -> None:
    offset = None
    print("VPS Simple bot polling...")
    while True:
        try:
            response = requests.get(
                f"{API}/getUpdates",
                params={"timeout": 30, "offset": offset},
                timeout=40,
            )
            for update in response.json().get("result", []):
                offset = update["update_id"] + 1
                handle(update)
        except Exception as error:  # noqa: BLE001 - keep the bot alive
            print("poll error:", error)
            time.sleep(3)


if __name__ == "__main__":
    main()
