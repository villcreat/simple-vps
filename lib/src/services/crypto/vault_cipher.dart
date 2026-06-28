import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart';

/// Shared authenticated-encryption primitives used by both the local
/// [SecretVault] and the portable export file: Argon2id key derivation plus
/// AES-256-GCM sealing. Keeping them in one place means the two crypto paths
/// cannot drift apart.
class VaultCipher {
  VaultCipher._();

  static final AesGcm aes = AesGcm.with256bits();

  // Argon2id parameters. Memory is in KiB; tuned to stay usable on mobile.
  static const int kdfMemory = 19456; // ~19 MiB
  static const int kdfIterations = 2;
  static const int kdfParallelism = 1;
  static const int keyLength = 32;
  static const int saltLength = 16;

  static Future<SecretKey> deriveKey(String password, List<int> salt) async {
    final kdf = Argon2id(
      memory: kdfMemory,
      iterations: kdfIterations,
      parallelism: kdfParallelism,
      hashLength: keyLength,
    );
    return kdf.deriveKey(
      secretKey: SecretKey(utf8.encode(password)),
      nonce: salt,
    );
  }

  static Future<Map<String, dynamic>> seal(
    SecretKey key,
    List<int> bytes,
  ) async {
    final box = await aes.encrypt(
      bytes,
      secretKey: key,
      nonce: aes.newNonce(),
    );
    return <String, dynamic>{
      'nonce': base64Encode(box.nonce),
      'cipher': base64Encode(box.cipherText),
      'mac': base64Encode(box.mac.bytes),
    };
  }

  static Future<List<int>> open(
    SecretKey key,
    Map<String, dynamic> box,
  ) async {
    final secretBox = SecretBox(
      base64Decode(box['cipher'] as String),
      nonce: base64Decode(box['nonce'] as String),
      mac: Mac(base64Decode(box['mac'] as String)),
    );
    return aes.decrypt(secretBox, secretKey: key);
  }

  static List<int> randomSalt() => randomBytes(saltLength);

  static List<int> randomBytes(int length) {
    final random = Random.secure();
    return List<int>.generate(length, (_) => random.nextInt(256));
  }
}
