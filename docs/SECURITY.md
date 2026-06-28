# Security

## Current State

- The app starts behind a master-password gate backed by an encrypted vault.
- Keys are derived with Argon2id; secrets are sealed with AES-256-GCM and held
  in memory only while the session is unlocked.
- Credentials (passwords / private keys) live in a separate encrypted file,
  never in the metadata store or source.
- Real SSH runs through `dartssh2`; dangerous scenarios require the risk phrase.
- A micro-backup of every touched file is taken before execution; execution
  stops on the first failure; rollback is explicit and reverse-order.
- Security events are logged for unlock, lock, add-server, install start/finish,
  and rollback.

## Implemented Safeguards

- [x] Store credentials with authenticated encryption (AES-256-GCM).
- [x] Derive keys with Argon2id.
- [x] Require the risk phrase for dangerous scenarios.
- [x] Create micro-backups before modifying remote files.
- [x] Explicit, user-triggered rollback only.
- [x] Auto-lock after idle timeout (configurable; clears the vault key).
- [x] Encrypted import/export with a separate file password.
- [x] SSH host-key pinning via `dartssh2`'s `onVerifyHostKey`: trust-on-first-use
      records the SHA256 fingerprint, later connects must match it (reject on
      mismatch). Clear a server's fingerprint to re-trust after a legit key change.

## Still Required Before Production

- [ ] Register keyboard activity for auto-lock (pointer activity is tracked;
      typing-only sessions are not yet counted as activity).
- [ ] Never execute `curl | bash` without preview and confirmation (no such
      scenario ships today; enforce when adding the instruction-search feature).

## Dangerous Actions

Examples:

- `rm -rf`
- changing SSH configuration
- changing firewall or VPN rules
- opening public ports
- downloading and executing external scripts
- rebooting the server
- stopping network services
