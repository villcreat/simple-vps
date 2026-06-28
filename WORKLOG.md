# Worklog

## 2026-06-28 — Full spec coverage (only release build remains)

Closed the remaining gaps against `VPS_SIMPLE_CODEX_FULL_PROMPT.md`:

- **Installed-service management (§9.1/§9.2/§20)** — `InstalledService.controlCommands`
  (label → command), derived at install time from the scenario shape (Docker
  Compose / systemd / Nginx). The installed-services screen shows a button per
  action that opens the terminal **pre-filled** with the command — editable, and
  dangerous commands still require the risk phrase. Plus copy-URL and delete-card.
- **SFTP file transfer (§6.4)** — `uploadFile` / `downloadFile` on `SshService`
  (dartssh2 `SftpClient`), a controller delegate, and a path-based `SftpScreen`
  reached from the server screen.
- **Server screen (§18)** — now lists the server's installed services; existing
  buttons cover install / passport / terminal / SFTP / check / edit / delete /
  reveal-credential.
- **Main screen three-dots (§16)** — server cards gained a popup menu
  (passport / terminal / delete) alongside the status chip and check button.
- **Auto-lock custom value (§25.3)** — the dropdown now offers "Custom…" and
  keeps any custom minute value.
- **Android target (§5)** — `flutter create --platforms=android .` generated the
  Android runner (build needs the Android SDK = part of the release step).

Also fixed a pre-existing **flaky test**: `export_service_test` checked that the
ciphertext doesn't contain `p1`, but `p`/`1` are base64 chars so it could match
random ciphertext — switched the marker to one containing `-`/`!` (not base64).

**Verified:** `flutter analyze` clean; `flutter test` → 33 passed; Windows GUI
rebuilt and relaunched.

Status: every functional point of the spec is implemented. Resource metrics
(CPU/RAM/disk/uptime/ports) are shown on the Server Passport screen (one tap)
rather than auto-polled inline on every list row. Only the release builds remain
(`flutter build windows`, and `flutter build apk` after Android SDK setup).

---

## 2026-06-28 — SSH host-key pinning (was thought blocked)

Re-checked the installed `dartssh2` 2.18.0 source: `SSHClient` *does* expose
`onVerifyHostKey` (`FutureOr<bool> Function(String type, Uint8List fingerprint)`,
fingerprint = OpenSSH `SHA256:<base64>`). The earlier "blocked" note was wrong —
made without the package on hand. Implemented trust-on-first-use pinning.

- `real_ssh_service.dart` — top-level `acceptHostFingerprint(pinned, observed)`
  (empty pinned ⇒ TOFU accept; otherwise must match) and an `onVerifyHostKey`
  hook on every connection; an `onHostFingerprint` callback reports the observed
  fingerprint for recording.
- `app_controller.dart` — wires `onHostFingerprint` to `_recordFingerprint`,
  which stores the fingerprint on the server the first time (persisted). Later
  connects are pinned; a mismatch is rejected (shows as a connection failure).
- `models.dart` — `Server.copyWith` also takes `hostFingerprint`.

A legit key change is handled by clearing the server's fingerprint (edit form).

**Verified:** `flutter analyze` clean; `flutter test` → 32 passed (+3:
TOFU-accept, match-accept, mismatch-reject); GUI rebuilt and relaunched.

---

## 2026-06-28 — Custom server groups (Stage 3 / spec §22.2)

Groups were a fixed built-in list; now users can manage their own.

- `models.dart` — `ServerGroup` JSON; `Server.copyWith` also takes `groupId`.
- `sample_data.dart` — `builtInGroupIds` / `isBuiltInGroup` (built-ins are
  protected from rename/delete).
- `app_controller.dart` — `addGroup` / `renameGroup` / `deleteGroup` (delete
  reassigns the group's servers to "personal"); custom groups load from and
  persist to the metadata store (built-ins always come from `SampleData`).
- `settings_screen.dart` — a "Server groups" card: list (built-in tagged),
  rename/delete for custom groups, and an add field. The server form's group
  dropdown already picks these up.
- New ru/en strings.

**Verified:** `flutter analyze` clean; `flutter test` → 29 passed (+2: group
add/rename/built-in-protection, and delete-reassigns-servers); GUI rebuilt and
relaunched.

---

## 2026-06-28 — Online/offline server status (Stage 3)

Filled the last Stage 3 gap: the server list always showed "Not checked".

- `models.dart` — `ServerStatus { unknown, checking, online, offline }` +
  `Server.copyWith` (for `lastConnectedAt`).
- `app_controller.dart` — ephemeral status maps + `checkServer` (probes via
  `sshService.checkConnection`, records online/offline + message, stamps
  `lastConnectedAt` on success) and `checkAllServers` (parallel).
- `server_list_screen.dart` — live colored status chip per server, a per-row
  check button (spinner while checking), and a "Check all" header button.
- `server_detail_screen.dart` — a "Check connection" button that probes and
  reports the result in a snackbar.
- New ru/en strings.

**Verified:** `flutter analyze` clean; `flutter test` → 27 passed (new
`checkServer` online↔offline test with a fake whose reachability is toggled);
rebuilt and relaunched the Windows GUI.

---

## 2026-06-28 — GUI run on Windows + back-button fix

Built and launched the Windows desktop app (debug) after adding the VS 2019
"Desktop development with C++" workload. Manual run surfaced a UX bug unit tests
didn't: `ServiceCatalogScreen` returns a bare `ListView` (designed to live inside
the home shell), so when `ServerDetailScreen` pushed it as a full route ("Install
service") there was no AppBar and **no back button** — a dead end. Fixed by
wrapping that push in a `Scaffold` with an `AppBar` (auto back arrow). All other
pushed screens already have their own `Scaffold`/`AppBar`.

Build/run: `flutter build windows --debug` →
`build\windows\x64\runner\Debug\vps_simple.exe`.

---

## 2026-06-27 — Milestone 3.1: Telegram bot (Stage 12)

The final roadmap stage — a separate Python service under `services/telegram-bot/`.

- `vaultfile.py` — decrypts the app's encrypted export with the *same* crypto
  (Argon2id m=19456/t=2/p=1/v=19 via `argon2-cffi`, AES-256-GCM via
  `cryptography`, GCM tag concatenated as the app stores it separately).
- `bot.py` — minimal long-poll bot (no heavy framework): access requires an
  allow-listed Telegram id **and** `/login <password>` (neither alone), then
  `/servers`, `/status <n>`, `/logs <n>` over SSH (`paramiko`). Read-only by
  design; host-key auto-add is flagged as a TODO.
- `requirements.txt`, `README.md` (deploy + security model).

**Verification (real, this session):**
- `dart run tool/export_fixture.dart` produced an encrypted export from the
  Flutter app.
- `python services/telegram-bot/test/test_vaultfile.py` decrypted it and
  rejected a wrong password — **interop confirmed** end-to-end.
- `python -m py_compile` clean on all bot files.

The live Telegram polling + SSH can't be exercised without a token and a real
server, but the security-critical file interop is proven.

This closes the Flutter + bot roadmap (Stages 1–8, 10, 11, 12). Remaining:
SSH host-key pinning (blocked on `dartssh2`), custom groups, SFTP, online status.

---

## 2026-06-27 — Verified: toolchain installed, analyze clean, tests green

Installed Flutter 3.44.4 (Dart 3.12.2) and ran the toolchain for the first time
against everything written this session.

- `flutter pub get` resolved all deps: dartssh2 2.18.0, cryptography 2.9.0,
  yaml 3.1.3.
- `flutter analyze` → **No issues found.**
- `flutter test` → **All 26 tests passed.**

Fixes that the first run surfaced:
- Real compile bug: `app_controller.dart` `Locale(language)` received `String?`
  (no promotion in the equality `if`) — added a `!= null` guard. This had blocked
  compilation of the controller (and any test importing it); it was carried over
  from the original scaffold.
- Clean-analyze cleanups: removed two unused `dart:io` imports, two redundant `!`
  assertions, switched `withOpacity`→`withValues`, `DropdownButtonFormField`
  `value`→`initialValue` (×3), and marked fully-literal `Scenario`/`ScenarioStep`
  invocations `const` (×8).

---

## 2026-06-27 — Milestone 3.0: plugin loader (Stage 11)

Third-party plugins, reusing the whole execution engine.

- Added the `yaml` dependency.
- `lib/src/services/plugin_loader.dart` — `PluginLoader` reads `plugin.yaml` +
  the per-OS `scripts/<os>.yaml`, normalizes YAML to maps, and `buildScenario`
  validates and produces a `category: plugin` `Scenario`. A destructive-looking
  command is forced to `dangerous` regardless of the declared flag. `Plugin`
  model + `PluginFormatException`. The `windows` entry key also matches
  `windows_server`.
- `app_controller.dart` — in-memory `plugins` list + `loadPlugin(dir, os)`.
- `plugins_screen.dart` — folder path + OS picker + Load, then a list of loaded
  plugins each with a Dry-run button that flows into the existing dry-run →
  execution → rollback path. (Previously a placeholder.)
- New ru/en strings; `pluginsStub` reworded to present tense.

Validation per spec §26.2 is satisfied by the shared flow: the dry-run shows
commands/files/ports/backups/dangerous actions, dangerous steps require the risk
phrase, and rollback uses each step's rollback command.

**Tests** — `test/plugin_loader_test.dart`: `buildScenario` happy path +
danger-forcing, four malformed-plugin rejections, and loading the bundled example
plugin from disk for Ubuntu and (via the short `windows` key) Windows Server.

**Docs:** ROADMAP, SCREENS, README, PLUGIN_SPEC, and the example plugin README.

Note: loaded plugins are session-only (not persisted); single-file/remote plugin
sources and a marketplace remain future work.

---

## 2026-06-26 — Milestone 2.6: server management (Stage 3)

Edit, delete, and credential reveal on the server screen.

- `app_controller.dart` — `updateServer` (in-place), `deleteServer` (cascades to
  the server's installed services, backups, and vault secret; logs a new
  `SecurityEventType.serverDeleted`), `credentialFor`, and `logSecretViewed`.
- `server_form_screen.dart` — now doubles as an edit form (`existing:` param):
  prefills fields, defaults the auth type from the stored credential, and treats
  a blank secret field as "keep current".
- `server_detail_screen.dart` — app-bar Edit/Delete actions (delete behind a
  confirm dialog) and a "Show credential" button that reveals the
  password/key in a dialog with copy-to-clipboard, logging `secretViewed`.
- New ru/en strings; `serverDeleted` added to the security-event enum.

**Tests** — `test/server_management_test.dart`: add/update/delete and the
delete cascade (in-memory store, no disk/SSH).

**Docs:** ROADMAP Stage 3, SCREENS, README updated.

---

## 2026-06-26 — Milestone 2.5: remaining website scenarios

Low-risk data-only addition. Extracted a shared `_staticSite` recipe in
`lib/src/data/install_scenarios.dart` and added `resume`, `bio`, `portfolio`, and
`weather` website scenarios (Nginx + a static page on port 80, dangerous steps
carry rollback). Added the four catalog entries and registered them in
`SampleData.scenarios`. No new UI or strings.

The existing `test/scenario_library_test.dart` automatically covers them
(catalog↔scenario mapping, dangerous⇒rollback invariant, run-to-success). Website
scenario READMEs updated.

---

## 2026-06-26 — Milestone 2.4: built-in SSH terminal (spec §19)

An interactive terminal on top of the existing `SshSession`.

**Shared safety helper** — `lib/src/services/command_safety.dart`:
- `CommandSafety.isDangerous` / `reasons` — one danger-pattern list (rm -rf, ufw
  allow, iptables, reboot, `curl|bash`, writes to `/etc`, …). `ScenarioEngine`
  now delegates its `_looksDangerous` here, so dry-run warnings and the terminal
  use the same rules.

**Terminal** — `lib/src/screens/ssh_terminal_screen.dart`:
- Opens one connection per screen; each command runs via `session.exec` with
  streamed stdout/stderr coloured by kind.
- Per-session command history (in a popup; intentionally **not** persisted to
  disk, since commands can contain secrets).
- A dangerous command opens a confirmation dialog that requires the risk phrase
  ("я понимаю риск" / "I understand the risk") before running, and logs a
  `dangerousCommandPreviewed` security event.
- No-credential / connecting / connection-error states with reconnect.
- Reached from the "Open terminal" button on the server screen (was a stub).

**Tests** — `test/command_safety_test.dart`: destructive vs ordinary commands and
`reasons`.

**Docs:** SCREENS, README, `core/ssh`, and ROADMAP touch-ups.

Known limitation: each command runs in a fresh shell (no persistent cwd) and
long-running/interactive commands (`top`, `tail -f`) can't be interrupted yet — a
PTY-based shell is the follow-up.

---

## 2026-06-26 — Milestone 2.3: server passport (Stage 5)

Live server inspection over the existing `SshSession`, replacing the `--`
placeholders on the server screen.

**Collection** — `lib/src/services/server_inspector.dart`:
- `ServerInspector.inspect(server)` runs one read-only command that bundles all
  probes behind `@@SECTION@@` markers (single round trip), then parses them into
  a `ServerPassport`: OS, kernel, uptime, CPU model/cores, load average, RAM,
  disk, listening ports, firewall state, Docker containers, Nginx sites, recent
  journal errors. Parsers are defensive (missing/empty output → sane fallbacks).
- `app_controller.dart` — `collectPassport(server)` delegates to the inspector
  and logs a new `SecurityEventType.serverInspected` event.

**UI** — `lib/src/screens/server_passport_screen.dart`:
- Sections for System / Network / Docker / Nginx / Installed services / Recent
  errors, with loading, error+retry, and no-credential states, plus a refresh
  action. Reached from a new "Server passport" button on the server screen.

**Tests** — `test/server_inspector_test.dart`: parses a realistic batched probe
(asserts OS, kernel, cores, ports `[22, 80]`, firewall, RAM, disk, Docker, Nginx,
filtered errors) and degrades gracefully on empty output. `fake_ssh_service.dart`
gained scripted per-command output.

**Docs:** SCREENS, ROADMAP Stage 5, README, and `core/server_inventory` updated.

Only read-only commands are used; `systemctl is-active`/`ss`/`df`/`free` avoid
needing sudo, so collection does not prompt. Docker/journal probes degrade to
"none" when not permitted without root.

---

## 2026-06-26 — Milestone 2.2: install scenarios + scenario-driven catalog

Stage 8. The execution engine, micro-backup, and rollback from Milestone 2 are
generic, so this step is mostly recipe data plus removing the 3X-UI hardcoding.

**New scenarios** — `lib/src/data/install_scenarios.dart`:
- `minecraft` — Java server as a systemd service, port 25565 (jar URL is a
  placeholder to set per version).
- `cs2` and `gmod` — SteamCMD dedicated servers (app ids 730 / 4020) via a shared
  `_steamGame` recipe, systemd service, ports 27015.
- `landing` — static page on Nginx, port 80.

Each dangerous step (port open, `/etc` config write, external download) carries a
`rollbackCommand`; a test enforces this invariant.

**Catalog is now scenario-driven** (no more hardcoded 3X-UI):
- `sample_data.dart` — `SampleData.scenarios` + `scenarioById(...)`; catalog lists
  all five as available.
- `app_controller.dart` — `scenarioById(...)`.
- `service_catalog_screen.dart` resolves the scenario for each card and passes it
  on; `dry_run_screen.dart` takes a `Scenario` and forwards it to the execution
  screen (the screens are no longer tied to 3X-UI).

**Tests:** `test/scenario_library_test.dart` — catalog↔scenario mapping, unique
ids, dangerous⇒rollback invariant, and every scenario runs to success over the
fake SSH session.

**Docs:** scenario READMEs (minecraft/cs2/gmod/landing) point to the recipes;
ROADMAP Stage 8 and README updated.

Note: recipes are reviewable starting points shown in full in the dry-run before
anything runs; the Minecraft jar URL is intentionally a placeholder.

---

## 2026-06-26 — Milestone 2.1: auto-lock + encrypted export/import

Follow-up hardening on top of Milestone 2.

**Auto-lock (Stage 2, spec §25.3)**
- `app_controller.dart` — `autoLockMinutes` (persisted), `registerActivity()`, and
  a 20s idle watchdog that calls `lock()` (clearing the vault key) after the
  configured idle time. Default 10 min; `0` disables it.
- `vps_simple_app.dart` — a `Listener` in `MaterialApp.builder` resets the idle
  timer on pointer activity.
- `settings_screen.dart` — auto-lock dropdown (Off / 5 / 10 / 15 / 30 min).

**Encrypted export/import (Stage 10, spec §24)**
- `lib/src/services/crypto/vault_cipher.dart` — extracted the shared Argon2id +
  AES-256-GCM primitives so the vault and the export file use one crypto path.
  `secret_vault.dart` now delegates to it and gained `exportSecrets()` /
  `importSecrets()`.
- `lib/src/services/crypto/export_service.dart` — `ExportService` builds/reads a
  versioned, password-protected file containing servers + their secrets;
  `ExportPasswordException` on a wrong password, `FormatException` on a bad file.
- `app_controller.dart` — `exportToFile` / `importFromFile` (merge by server id,
  import secrets into the vault, security events).
- `settings_screen.dart` — export/import card (file path + separate passwords).

**Tests:** `test/export_service_test.dart` (round-trip, wrong password, bad file).

**Deliberately deferred:** SSH host-key pinning — `dartssh2` exposes no stable
host-key verify hook, so it needs a verified package API or a small fork; left as
the top open security item.

---

## 2026-06-26 — Milestone 2: real SSH, encrypted secrets, execution, rollback

This milestone closes the four previously-unchecked items from the README:
**encrypted secret storage, real SSH, real scenario execution, and rollback.**
They were built as one vertical so the pieces fit together safely.

### What landed

**1. Encrypted secret storage (Stage 2)**
- `lib/src/services/crypto/secret_vault.dart` — `SecretVault`: Argon2id key
  derivation + AES-256-GCM. Seals a verifier token (for password checks) and the
  credential map. Secrets are decrypted into memory only while unlocked.
- `lib/src/services/crypto/encrypted_secret_store.dart` — stores the encrypted
  envelope in `vps_simple_secrets.json`, separate from metadata.
- `lib/src/services/app_paths.dart` — shared per-user data directory; both stores
  use it. `local_json_store.dart` refactored onto it.
- Master password is now real: first launch creates the vault; later launches
  verify against it (wrong password is rejected via the GCM MAC).

**2. Real SSH (Stage 4)**
- `lib/src/services/ssh_service.dart` — extended boundary: `SshSession`,
  `SshChunk`, `SshCredential`; `StubSshService` keeps the no-network fallback.
- `lib/src/services/real_ssh_service.dart` — `RealSshService` over `dartssh2`
  (pure Dart → works on desktop and Android). Password or private-key auth;
  credentials pulled from the vault at connect time. One streaming session per run.

**3. Real scenario execution (Stage 6)**
- `lib/src/services/execution/scenario_runner.dart` — `ScenarioRunner` + the
  `ExecutionEvent` / `StepStatus` / `RunPhase` types. Refuses dangerous scenarios
  without confirmation, micro-backs-up touched files, runs steps over one session,
  streams logs + per-step status, stops on the first non-zero exit code.
- `lib/src/screens/execution_screen.dart` — risk-phrase gate, live monospace log,
  per-step status icons, result, and rollback button. Reached from the dry-run
  screen's confirm button (no longer a stub).

**4. Rollback (Stage 7)**
- `lib/src/services/execution/rollback_runner.dart` — `RollbackRunner` runs each
  executed step's `rollbackCommand` in reverse, on explicit user action only.
- `ScenarioStep.rollbackCommand` added; the 3X-UI sample + YAML now define
  rollback commands for the dangerous steps.

**Wiring & data**
- `app_controller.dart` — owns the vault + `RealSshService`, exposes
  `unlockOrSetup`, `runScenario`, `rollbackLastRun`, credential setters; records
  installed services, backups, and install history; persists them all.
- Models gained JSON for `InstalledService` / `InstallHistory` / `Backup` and an
  `executedStepIds` field + `copyWith` on history.
- `installed_services`, `logs`, and `backups` screens now render real data.
- `server_form_screen.dart` captures a password or key and stores it in the vault.
- New ru/en strings in `app_strings.dart`. Version bumped to `0.2.0+2`.

### How to build and verify

Flutter/Dart were **not installed on the build machine**, so the code below was
written but not compiled here. On a machine with Flutter (3.22+):

```powershell
cd vps-simple
flutter pub get      # downloads dartssh2 + cryptography (needs internet)
flutter analyze
flutter test
```

Tests added:
- `test/secret_vault_test.dart` — password round-trip, wrong-password rejection,
  no plaintext on disk.
- `test/scenario_runner_test.dart` — full run, abort-without-confirmation,
  stop-on-failure, unsupported-OS abort (uses `test/fake_ssh_service.dart`).
- `test/rollback_runner_test.dart` — reverse-order rollback, skip steps with no
  rollback command.

Manual smoke test: launch the app → set a master password → add a real test VPS
with a password → Catalog → 3X-UI → Dry-run → Confirm → type `я понимаю риск` →
watch the live log → use **Roll back changes**.

### Known limitations / risks

- **Not compiled locally.** The pure-logic (vault, runner, rollback, models) is
  covered by tests; the `dartssh2` calls in `real_ssh_service.dart` use the
  documented stable API but should be confirmed with `flutter analyze` after
  `pub get`. Any fix is isolated to that one file.
- **Host-key pinning not enforced.** `Server.hostFingerprint` is captured but not
  checked on connect — `dartssh2` does not expose a stable verify hook here.
  Verify hosts manually until this lands.
- **Backups are file copies + rollback commands**, not provider snapshots, and
  there is no restore-from-copy UI yet.
- **`sudo` assumed non-interactive.** Backup/exec commands use `sudo`; a server
  that prompts for a sudo password will fail those steps.

### Next steps

1. `flutter pub get` + `flutter analyze` + `flutter test`; fix any `dartssh2` API
   drift.
2. SSH host-key pinning + auto-lock timeout.
3. Encrypted import/export between devices (reuses the vault crypto).
4. More scenarios (Minecraft, CS2, websites) and the plugin loader.
