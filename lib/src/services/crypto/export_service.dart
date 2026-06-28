import 'dart:convert';

import 'package:cryptography/cryptography.dart';

import '../../models/models.dart';
import 'vault_cipher.dart';

/// Thrown when an import file cannot be decrypted with the supplied password.
class ExportPasswordException implements Exception {
  const ExportPasswordException();

  @override
  String toString() => 'Wrong export password.';
}

/// Result of reading an encrypted export file.
class ImportResult {
  const ImportResult({required this.servers, required this.secrets});

  final List<Server> servers;
  final Map<String, dynamic> secrets;
}

/// Builds and reads the encrypted file used to move servers between devices.
///
/// The file is protected by its own password (separate from the master
/// password), carries a format version, and seals the server list together with
/// their credentials using the same Argon2id + AES-256-GCM as the local vault.
class ExportService {
  static const String _magic = 'vps-simple-export';
  static const int formatVersion = 1;

  Future<String> buildExport({
    required String password,
    required List<Server> servers,
    required Map<String, dynamic> secrets,
  }) async {
    final salt = VaultCipher.randomSalt();
    final key = await VaultCipher.deriveKey(password, salt);

    final payload = jsonEncode(<String, dynamic>{
      'servers': servers.map((server) => server.toJson()).toList(),
      'secrets': secrets,
    });
    final box = await VaultCipher.seal(key, utf8.encode(payload));

    const encoder = JsonEncoder.withIndent('  ');
    return encoder.convert(<String, dynamic>{
      'format': _magic,
      'version': formatVersion,
      'kdf': 'argon2id',
      'salt': base64Encode(salt),
      'payload': box,
    });
  }

  Future<ImportResult> readImport({
    required String password,
    required String content,
  }) async {
    final dynamic data = jsonDecode(content);
    if (data is! Map || data['format'] != _magic) {
      throw const FormatException('Not a VPS Simple export file.');
    }

    final version = data['version'];
    if (version is! int || version > formatVersion) {
      throw const FormatException('Unsupported export file version.');
    }

    final salt = base64Decode(data['salt'] as String);
    final key = await VaultCipher.deriveKey(password, salt);

    final List<int> clear;
    try {
      clear = await VaultCipher.open(
        key,
        (data['payload'] as Map).cast<String, dynamic>(),
      );
    } on SecretBoxAuthenticationError {
      throw const ExportPasswordException();
    }

    final payload = jsonDecode(utf8.decode(clear)) as Map<String, dynamic>;
    final servers = (payload['servers'] as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(Server.fromJson)
        .toList();
    final secrets = (payload['secrets'] as Map? ?? const {})
        .cast<String, dynamic>();

    return ImportResult(servers: servers, secrets: secrets);
  }
}
