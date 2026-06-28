# VPS Simple

VPS Simple is a Flutter scaffold for a safe, cross-platform VPS management app.
The first milestone focuses on the foundation: navigation, local server records,
themes, ru/en UI strings, models, SSH/scenario stubs, and a dry-run preview for
the first service scenario.

The product principle is simple: help manage VPS servers without surprising the
user or breaking their infrastructure.

## Current State

- Flutter app shell with desktop/mobile responsive navigation.
- Master-password gate that creates/verifies an encrypted vault (Argon2id + AES-256-GCM).
- Encrypted secret storage: passwords and SSH keys are sealed in a separate file
  and only held in memory while the session is unlocked.
- Real SSH over the pure-Dart `dartssh2` client (password or key auth), so the
  same path works on desktop and Android.
- Scenario execution over one SSH session with a live log and per-step status.
- Server passport: live OS, CPU, RAM, disk, uptime, ports, firewall, Docker,
  Nginx, and recent errors collected read-only over SSH.
- Built-in SSH terminal: streamed output, per-session command history, and a
  risk-phrase prompt before any command flagged as dangerous.
- Micro-backups before file changes and one-tap rollback of the last run.
- Idle auto-lock that clears the vault key, configurable in settings.
- Encrypted export/import of servers + secrets between devices (separate password).
- Plugin loader: read a YAML plugin folder for an OS and run it through the same
  dry-run, confirmation, and rollback as the built-in catalog.
- Telegram bot under `services/telegram-bot/` (Python): reads the encrypted
  export, gates access by password + allowed Telegram id, and shows server
  status/logs over SSH.
- Light, dark, and system theme modes; Russian and English UI string table.
- Local JSON persistence for non-secret metadata, installed services, backups,
  and install history.
- Server list, add/edit-server form (with credential capture), server card with
  delete and reveal/copy-credential actions, a scenario-driven catalog (3X-UI,
  Minecraft, CS2, Garry's Mod, websites), dry-run preview, and a live execution
  screen.
- Security log entries for unlock, lock, add-server, install start/finish, and
  rollback.
- Documentation under `docs/`; see `WORKLOG.md` for the latest milestone.

## Important Safety Notes

Execution is real now, but kept behind guardrails: dangerous scenarios refuse to
run until the user types the risk phrase, a micro-backup is taken before any file
change, execution stops on the first failing step, and rollback is only ever
triggered by an explicit user action.

Do not store real passwords, private keys, or production secrets in examples or
source files. Real credentials entered in the app go only into the encrypted
vault, never into the metadata store or source.

SSH host keys are pinned trust-on-first-use: the first connection records the
server's SHA256 fingerprint and later connections must match it (a mismatch is
rejected). Clear a server's fingerprint to re-trust after a legitimate key change.

## Run Locally

Flutter is required. If the platform runner folders are not present yet, create
them once from the project root:

```powershell
flutter create --platforms=windows,linux,macos,android .
```

Then run (the first `pub get` downloads `dartssh2` and `cryptography`, so it
needs internet access):

```powershell
flutter pub get
flutter run
```

Run tests and static analysis:

```powershell
flutter analyze
flutter test
```

## First Milestone Checklist

- [x] Repository structure.
- [x] README and documentation.
- [x] Base Flutter app code.
- [x] Navigation sections.
- [x] Light and dark themes.
- [x] ru/en localization table.
- [x] Data models.
- [x] SSH service stub.
- [x] Scenario engine stub.
- [x] Add-server screen.
- [x] Server card screen.
- [x] Dry-run screen.
- [x] 3X-UI sample scenario.
- [x] Real SSH connection (`dartssh2`, password/key auth).
- [x] Encrypted secret storage (Argon2id + AES-256-GCM vault).
- [x] Real scenario execution (live log, per-step status, micro-backup).
- [x] Rollback execution (explicit, reverse-order rollback commands).
- [x] Auto-lock after idle timeout (configurable in settings).
- [x] Encrypted import/export between devices (separate file password).
- [x] Install scenarios: 3X-UI, Minecraft, CS2, Garry's Mod, landing page.
- [x] Server passport (live metrics over SSH).
- [x] Built-in SSH terminal with dangerous-command confirmation.
- [x] Website scenarios: landing, resume, bio, portfolio, weather.
- [x] Edit/delete servers and reveal/copy stored credentials.
- [x] Plugin loader (YAML manifests, reviewed via dry-run + rollback).
- [x] Telegram bot (Python; reads the encrypted export, password + Telegram id).
- [x] Online/offline server status (SSH connection check in the UI).
- [x] Custom server groups (add / rename / delete, persisted).
- [x] SSH host-key pinning on connect (trust-on-first-use).
- [x] SFTP file upload/download.
- [x] Installed-service management buttons (start/stop/restart/update/logs, editable + danger-confirmed).
- [x] Android build target generated.

Every feature in the original spec is implemented and covered by `flutter analyze`
(clean) + `flutter test` (all green). What's left is producing the release builds:
`flutter build windows` (and `flutter build apk` once the Android SDK is set up).
