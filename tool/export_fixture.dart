// Generates an encrypted export fixture for the Telegram bot interop test.
// Run from the project root:  dart run tool/export_fixture.dart
import 'dart:io';

import 'package:vps_simple/src/models/models.dart';
import 'package:vps_simple/src/services/crypto/export_service.dart';

Future<void> main() async {
  final servers = [
    Server(
      id: 's1',
      name: 'Alpha',
      host: '203.0.113.10',
      sshPort: 22,
      os: ServerOs.ubuntu,
      username: 'root',
      groupId: 'personal',
      note: 'fixture',
      secretReference: 's1',
      hostFingerprint: '',
      createdAt: DateTime(2026, 6, 27),
    ),
  ];
  final secrets = <String, dynamic>{
    's1': {'type': 'password', 'password': 'hunter2'},
  };

  final content = await ExportService().buildExport(
    password: 'fixture-pass',
    servers: servers,
    secrets: secrets,
  );

  final out = File('services/telegram-bot/test/fixture_export.json');
  await out.parent.create(recursive: true);
  await out.writeAsString(content);
  stdout.writeln('wrote ${out.path}');
}
