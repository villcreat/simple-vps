import 'package:flutter_test/flutter_test.dart';
import 'package:vps_simple/src/services/crypto/encrypted_secret_store.dart';
import 'package:vps_simple/src/services/crypto/secret_vault.dart';

/// Keeps the encrypted envelope in memory so the test never touches disk.
class _MemoryStore extends EncryptedSecretStore {
  Map<String, dynamic>? data;

  @override
  Future<Map<String, dynamic>?> read() async => data;

  @override
  Future<void> write(Map<String, dynamic> envelope) async {
    data = envelope;
  }

  @override
  Future<bool> exists() async => data != null;
}

void main() {
  test('round-trips a password secret and rejects the wrong master password',
      () async {
    final store = _MemoryStore();

    final vault = SecretVault(store: store);
    expect(await vault.isInitialized(), isFalse);

    await vault.setup('correct horse battery');
    expect(vault.isUnlocked, isTrue);
    await vault.putPassword('srv', 's3cret-pass');

    // Simulate a fresh launch backed by the same encrypted file.
    final reopened = SecretVault(store: store);
    expect(await reopened.isInitialized(), isTrue);

    expect(await reopened.unlock('wrong password'), isFalse);
    expect(reopened.isUnlocked, isFalse);

    expect(await reopened.unlock('correct horse battery'), isTrue);
    final credential = reopened.credentialFor('srv');
    expect(credential, isNotNull);
    expect(credential!.password, 's3cret-pass');
    expect(credential.isKey, isFalse);
  });

  test('persists nothing in plain text', () async {
    final store = _MemoryStore();
    final vault = SecretVault(store: store);
    await vault.setup('master');
    await vault.putPassword('srv', 'super-secret-value');

    final serialized = store.data.toString();
    expect(serialized.contains('super-secret-value'), isFalse);
    expect(serialized.contains('master'), isFalse);
  });
}
