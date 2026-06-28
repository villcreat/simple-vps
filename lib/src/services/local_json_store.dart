import 'dart:convert';

import 'app_paths.dart';

/// Stores non-secret metadata (servers, settings, history) as a JSON file.
/// Secrets never live here — they go to the encrypted vault instead.
class LocalJsonStore {
  LocalJsonStore({this.fileName = 'vps_simple_store.json'});

  final String fileName;

  Future<Map<String, dynamic>> read() async {
    final file = await AppPaths.file(fileName);
    if (!await file.exists()) {
      return <String, dynamic>{};
    }

    final raw = await file.readAsString();
    if (raw.trim().isEmpty) {
      return <String, dynamic>{};
    }

    final decoded = jsonDecode(raw);
    return decoded is Map<String, dynamic> ? decoded : <String, dynamic>{};
  }

  Future<void> write(Map<String, dynamic> data) async {
    final file = await AppPaths.file(fileName);
    await file.parent.create(recursive: true);
    const encoder = JsonEncoder.withIndent('  ');
    await file.writeAsString(encoder.convert(data), flush: true);
  }
}
