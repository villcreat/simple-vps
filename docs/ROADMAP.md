# Roadmap

## Stage 1: Project Scaffold

- Flutter app shell.
- Navigation.
- Themes.
- ru/en UI strings.
- Models.
- Server form and server card.
- SSH and scenario stubs.
- 3X-UI dry-run.

## Stage 2: Local Security

- [x] Master password setup and verification.
- [x] Encrypted secret storage (Argon2id + AES-256-GCM vault).
- [x] Auto-lock (idle timeout, configurable in settings).
- [x] Security settings (theme, language, auto-lock, export/import).

## Stage 3: Servers

- [x] Edit server.
- [x] Delete server (cascades to its services, backups, and vault secret).
- [x] Reveal / copy stored credential (logged as a security event).
- [x] Server groups (built-in + custom: add / rename / delete in Settings).
- [x] SSH connection check (in UI: per-server and "check all").
- [x] Online/offline status (live chip on the server list).

## Stage 4: SSH Core

- [x] Password auth.
- [x] Key auth.
- [x] Command execution.
- [x] Streaming terminal output (`SshSession.exec`).
- [x] File upload/download (SFTP).

## Stage 5: Server Passport

- [x] OS, CPU, RAM, disk.
- [x] Uptime.
- [x] Ports.
- [x] Firewall.
- [x] Docker.
- [x] Nginx.
- [x] Recent errors.
- [ ] Domains and per-provider snapshots.

## Stage 6: Scenario Engine

- [x] YAML/JSON sample recipe + in-app scenario model.
- [x] Dry-run validation.
- [x] Dangerous command detection.
- [x] Confirmation (risk phrase).
- [x] Live step status.

## Stage 7: Backups And Rollback

- [x] Micro-backups (pre-install copy of touched files).
- [x] Rollback (reverse-order rollback commands).
- [x] Rollback history (marked on the install history entry).

## Stage 8: First Services

- [x] 3X-UI.
- [x] Minecraft.
- [x] CS2.
- [x] Garry's Mod.
- [x] Simple websites (landing, resume, bio, portfolio, weather).

## Later

- Android UX hardening.
- [x] Encrypted import/export (path-based; file-picker UX still to add).
- [x] Plugin loading (YAML manifests via the same dry-run/rollback flow).
- [x] Telegram bot (Python; reads the encrypted export, password + allowed id).
- [x] SSH host-key pinning (trust-on-first-use via `dartssh2.onVerifyHostKey`).
