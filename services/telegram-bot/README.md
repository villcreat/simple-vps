# Telegram Bot

A simple, read-mostly alternative interface for VPS Simple. It runs on its own
VPS, reads the server list from the app's **encrypted export file**, and is a
secondary interface — never a sync server.

## Security model

Access requires **both** an allow-listed Telegram id **and** a password
(`/login`). Neither alone is enough (per the spec). The server file stays
encrypted on disk and is decrypted in memory using the same Argon2id +
AES-256-GCM as the app.

## Setup

```bash
python3 -m venv .venv && . .venv/bin/activate   # optional
pip install -r requirements.txt
```

Export your servers from the app (Settings → Export) with a file password, copy
the resulting `*.json` to the bot host, then set:

```bash
export BOT_TOKEN=123:ABC                 # from @BotFather
export BOT_PASSWORD=choose-a-password
export ALLOWED_TELEGRAM_IDS=11111111,22222222
export EXPORT_FILE=/opt/vps-simple/servers.json
export EXPORT_PASSWORD=the-file-password
python bot.py
```

Run it under systemd or `screen`/`tmux` to keep it alive.

## Commands

- `/login <password>` — unlock this session (id must also be allow-listed)
- `/servers` — list servers
- `/status <n>` — `uname`, uptime, disk, memory over SSH
- `/logs <n>` — recent journal/syslog lines over SSH

Actions are intentionally read-only in this version (the bot is the
least-trusted interface). SSH auth (password or private key) comes from the
encrypted file.

## Interop test

`test/test_vaultfile.py` decrypts a fixture produced by the Dart app, proving the
bot reads exactly what the app writes. Regenerate the fixture from the app repo
root and run the test:

```bash
dart run tool/export_fixture.dart                 # writes test/fixture_export.json
python services/telegram-bot/test/test_vaultfile.py
```

## Limitations / TODO

- Host keys are auto-added (`AutoAddPolicy`); pin them once the app does.
- `/login` state is in-memory (resets on restart).
- Only read-only commands; write actions would need the app's confirmation flow.
