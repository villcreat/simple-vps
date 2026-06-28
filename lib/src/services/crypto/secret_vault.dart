import 'dart:convert';

import 'package:cryptography/cryptography.dart';

import '../ssh_service.dart';
import 'encrypted_secret_store.dart';
import 'vault_cipher.dart';

/// Authenticated-encryption vault for server credentials.
///
/// The master password is stretched with Argon2id and the resulting key seals
/// both a verifier token and the secret map with AES-256-GCM. Secrets are only
/// ever held in memory while the vault is unlocked; on disk they remain
/// encrypted in a file separate from non-secret metadata.
class SecretVault {
  SecretVault({EncryptedSecretStore? store})
      : _store = store ?? EncryptedSecretStore();

  final EncryptedSecretStore _store;

  static const String _verifierPlainText = 'vps-simple-vault-v1';
  static const int _formatVersion = 1;

  SecretKey? _key;
  Map<String, dynamic> _secrets = <String, dynamic>{};
  Map<String, dynamic>? _envelope;

  bool get isUnlocked => _key != null;

  /// True when a vault file already exists, i.e. the master password is set.
  Future<bool> isInitialized() async {
    final data = await _store.read();
    return data != null && data['version'] != null;
  }

  /// Creates a brand-new vault protected by [masterPassword].
  Future<void> setup(String masterPassword) async {
    final salt = VaultCipher.randomSalt();
    final key = await VaultCipher.deriveKey(masterPassword, salt);
    final verifier =
        await VaultCipher.seal(key, utf8.encode(_verifierPlainText));
    final secrets =
        await VaultCipher.seal(key, utf8.encode(jsonEncode(<String, dynamic>{})));

    final envelope = <String, dynamic>{
      'version': _formatVersion,
      'kdf': 'argon2id',
      'kdfParams': <String, dynamic>{
        'memory': VaultCipher.kdfMemory,
        'iterations': VaultCipher.kdfIterations,
        'parallelism': VaultCipher.kdfParallelism,
        'hashLength': VaultCipher.keyLength,
      },
      'salt': base64Encode(salt),
      'verifier': verifier,
      'secrets': secrets,
    };

    await _store.write(envelope);
    _key = key;
    _secrets = <String, dynamic>{};
    _envelope = envelope;
  }

  /// Verifies [masterPassword] against an existing vault. Returns false on a
  /// wrong password; loads the decrypted secret map into memory on success.
  Future<bool> unlock(String masterPassword) async {
    final data = await _store.read();
    if (data == null || data['version'] == null) {
      return false;
    }

    final salt = base64Decode(data['salt'] as String);
    final key = await VaultCipher.deriveKey(masterPassword, salt);

    try {
      final verifierBytes = await VaultCipher.open(
        key,
        (data['verifier'] as Map).cast<String, dynamic>(),
      );
      if (utf8.decode(verifierBytes) != _verifierPlainText) {
        return false;
      }

      final secretBytes = await VaultCipher.open(
        key,
        (data['secrets'] as Map).cast<String, dynamic>(),
      );
      final decoded = jsonDecode(utf8.decode(secretBytes));
      _secrets =
          decoded is Map<String, dynamic> ? decoded : <String, dynamic>{};
      _key = key;
      _envelope = data;
      return true;
    } on SecretBoxAuthenticationError {
      // Wrong password -> MAC verification fails.
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Drops the derived key and decrypted secrets from memory.
  void lock() {
    _key = null;
    _secrets = <String, dynamic>{};
    _envelope = null;
  }

  bool hasSecret(String reference) => _secrets.containsKey(reference);

  /// Resolves a stored credential for [reference], or null if none exists.
  SshCredential? credentialFor(String reference) {
    final raw = _secrets[reference];
    if (raw is! Map) {
      return null;
    }

    final map = raw.cast<String, dynamic>();
    if (map['type'] == 'key') {
      return SshCredential.key(
        map['privateKeyPem'] as String? ?? '',
        passphrase: map['passphrase'] as String?,
      );
    }
    return SshCredential.password(map['password'] as String? ?? '');
  }

  Future<void> putPassword(String reference, String password) async {
    _ensureUnlocked();
    _secrets[reference] = <String, dynamic>{
      'type': 'password',
      'password': password,
    };
    await _persistSecrets();
  }

  Future<void> putKey(
    String reference,
    String privateKeyPem, {
    String? passphrase,
  }) async {
    _ensureUnlocked();
    _secrets[reference] = <String, dynamic>{
      'type': 'key',
      'privateKeyPem': privateKeyPem,
      if (passphrase != null && passphrase.isNotEmpty) 'passphrase': passphrase,
    };
    await _persistSecrets();
  }

  Future<void> remove(String reference) async {
    _ensureUnlocked();
    _secrets.remove(reference);
    await _persistSecrets();
  }

  /// Returns a copy of the decrypted secret map for export. Empty when locked.
  Map<String, dynamic> exportSecrets() {
    if (_key == null) {
      return <String, dynamic>{};
    }
    return Map<String, dynamic>.of(_secrets);
  }

  /// Merges [incoming] secrets (e.g. from an import file) and re-seals the vault.
  Future<void> importSecrets(Map<String, dynamic> incoming) async {
    _ensureUnlocked();
    _secrets.addAll(incoming);
    await _persistSecrets();
  }

  Future<void> _persistSecrets() async {
    final envelope = _envelope;
    final key = _key;
    if (envelope == null || key == null) {
      return;
    }
    envelope['secrets'] =
        await VaultCipher.seal(key, utf8.encode(jsonEncode(_secrets)));
    await _store.write(envelope);
  }

  void _ensureUnlocked() {
    if (_key == null) {
      throw StateError('Vault is locked.');
    }
  }
}
