# Encryption Core

Implemented in `lib/src/services/crypto/`:

- `secret_vault.dart` — `SecretVault`: Argon2id key derivation and AES-256-GCM
  sealing of a verifier token plus the credential map. Master-password setup and
  verification live here.
- `encrypted_secret_store.dart` — persists the encrypted envelope in a separate
  file from the non-secret metadata store.

TODO: encrypted import/export with a separate file password; auto-lock timeout.
