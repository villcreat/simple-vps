# Technical Specification

## Goal

VPS Simple is a cross-platform app for managing personal VPS servers through a
safe workflow:

```text
server -> service -> dry-run -> preview -> confirmation -> live log -> service card
```

## Platforms

- Desktop first: Windows, Linux, macOS.
- Android in MVP with a simplified layout.
- Telegram bot after the desktop and Android core are stable.

## MVP Features

- Master-password session gate.
- Local server list.
- SSH connection checks.
- Server status and resource metrics.
- Service catalog.
- Dry-run for every install scenario.
- Installation preview with commands, files, ports, backups, and warnings.
- Live logs when execution is implemented.
- Installed service cards.
- Micro-backups and rollback by explicit user action.
- Encrypted import/export.

## First Scaffold Scope

The current scaffold implements app structure and safe previews only. Real SSH,
secret encryption, command execution, and rollback are intentionally deferred.

## Non-Goals For The First Milestone

- Telegram bot.
- Marketplace.
- Internet instruction search.
- Automatic execution of downloaded scripts.
- Provider snapshots.
- Cloud synchronization.
