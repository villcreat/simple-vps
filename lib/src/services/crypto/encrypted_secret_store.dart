import 'dart:convert';

import '../app_paths.dart';

/// Persists the encrypted secret vault envelope as a separate JSON file, kept
/// apart from the non-secret metadata store.
class EncryptedSecretStore {
  EncryptedSecretStore({this.fileName = 'vps_simple_secrets.json'});

  final String fileName;

  Future<Map<String, dynamic>?> read() async {
    final file = await AppPaths.file(fileName);
    if (!await file.exists()) {
      return null;
    }

    final raw = await file.readAsString();
    if (raw.trim().isEmpty) {
      return null;
    }

    final decoded = jsonDecode(raw);
    return decoded is Map<String, dynamic> ? decoded : null;
  }

  Future<void> write(Map<String, dynamic> envelope) async {
    final file = await AppPaths.file(fileName);
    await file.parent.create(recursive: true);
    const encoder = JsonEncoder.withIndent('  ');
    await file.writeAsString(encoder.convert(envelope), flush: true);
  }

  Future<bool> exists() async {
    final file = await AppPaths.file(fileName);
    return file.exists();
  }
}
