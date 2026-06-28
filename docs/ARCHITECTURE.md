# Architecture

## Layers

- `lib/src/screens`: user interface screens (incl. the live execution screen).
- `lib/src/models`: domain models with JSON serialization.
- `lib/src/services`: local storage, SSH boundary, scenario engine.
  - `services/crypto`: `SecretVault` (Argon2id + AES-256-GCM) and its file store.
  - `services/execution`: `ScenarioRunner`, `RollbackRunner`, and execution events.
  - `services/real_ssh_service.dart`: production `dartssh2` client.
- `lib/src/data`: built-in catalog and sample scenarios.
- `scenarios`: structured scenario recipes.
- `docs`: product, security, roadmap, and plugin documentation.

## Safety Boundary

The UI never executes shell commands directly. It asks the `ScenarioEngine` for a
dry-run report, and only the `ScenarioRunner` runs approved steps through the
`SshService`. Every run keeps preview, confirmation, backup, logging, and
rollback in one controlled flow:

- dangerous scenarios refuse to run without the typed risk phrase;
- a micro-backup of every touched file is taken before execution;
- execution stops on the first non-zero exit code;
- rollback runs explicit per-step rollback commands in reverse, on user request.

## Components

- `SecretVault`: derives a key from the master password with Argon2id and seals a
  verifier token plus the secret map with AES-256-GCM. Secrets live in memory
  only while unlocked; on disk they stay encrypted in `vps_simple_secrets.json`.
- `SshService` / `SshSession`: the transport boundary. `RealSshService` opens one
  session per run and streams stdout/stderr as `SshChunk`s ending in an exit code.
  `StubSshService` never touches the network (tests, safe fallback).
- `ScenarioRunner`: orchestrates a run and emits `ExecutionEvent`s (log lines,
  per-step status, run phase) consumed by the execution screen.
- `RollbackRunner`: reverts a completed run using each step's `rollbackCommand`.

## Scenario Flow

1. Load a structured scenario and match it to the server OS.
2. Build a dry-run report (commands, files, ports, backups, dangerous actions).
3. Require the risk phrase for dangerous scenarios.
4. Open one SSH session; take a micro-backup of touched files.
5. Run each step, streaming logs and per-step status; stop on first failure.
6. On success, create an installed-service card, backup record, and history entry.
7. Offer explicit rollback of the last run.

## Storage

Non-secret metadata (servers, settings, installed services, backups, history)
lives in `vps_simple_store.json`. Credentials are kept only in the encrypted
vault file, never alongside metadata or in source.
