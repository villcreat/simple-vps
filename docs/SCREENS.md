# Screens

## Implemented

- Lock screen (master-password setup on first launch, verify afterwards).
- Servers.
- Add / edit server (with password/key credential capture into the vault).
- Server card (install / passport / terminal / SFTP / check-connection / edit /
  delete / reveal-credential actions; lists the server's installed services).
- Server list cards: live online/offline status, per-row check, and a
  three-dots menu (passport / terminal / delete).
- Service catalog.
- Dry-run preview.
- Execution screen (risk phrase, live log, per-step status, rollback).
- Installed services with management buttons (start / stop / restart / update /
  logs — open the terminal pre-filled, editable and danger-confirmed) and delete.
- SFTP transfer screen (upload / download by path).
- Logs (install history).
- Backups (real backup records).
- Settings (auto-lock incl. custom value, encrypted export/import, server groups).
- Plugins (load a plugin folder per OS, then dry-run/execute it).
- Security log.
- Server passport (live OS / CPU / RAM / disk / ports / firewall / Docker /
  Nginx / recent errors collected over SSH).
- Built-in SSH terminal (streamed output, per-session history, risk-phrase
  confirmation for dangerous commands).

## Expected Next Screens

- Backup detail / restore picker.
- Interactive PTY terminal with persistent shell state (current terminal runs
  each command in a fresh shell).
