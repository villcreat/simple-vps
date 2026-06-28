import 'package:flutter_test/flutter_test.dart';
import 'package:vps_simple/src/models/models.dart';
import 'package:vps_simple/src/services/crypto/export_service.dart';

Server _server(String id) {
  return Server(
    id: id,
    name: 'VPS $id',
    host: '203.0.113.$id',
    sshPort: 22,
    os: ServerOs.ubuntu,
    username: 'root',
    groupId: 'personal',
    note: '',
    secretReference: id,
    hostFingerprint: '',
    createdAt: DateTime(2026, 6, 26),
  );
}

void main() {
  final service = ExportService();

  test('round-trips servers and secrets through an encrypted file', () async {
    final content = await service.buildExport(
      password: 'file-password',
      servers: [_server('1'), _server('2')],
      secrets: {
        '1': {'type': 'password', 'password': 'pw-one!'},
        '2': {'type': 'password', 'password': 'pw-two!'},
      },
    );

    // Nothing sensitive leaks into the file text. The markers contain `-`/`!`,
    // which are not base64 characters, so they cannot appear in the ciphertext
    // by chance.
    expect(content.contains('pw-one!'), isFalse);
    expect(content.contains('203.0.113.1'), isFalse);

    final result =
        await service.readImport(password: 'file-password', content: content);
    expect(result.servers.map((s) => s.id), ['1', '2']);
    expect(result.secrets['1'], {'type': 'password', 'password': 'pw-one!'});
  });

  test('rejects a wrong file password', () async {
    final content = await service.buildExport(
      password: 'right',
      servers: [_server('1')],
      secrets: const {},
    );

    expect(
      () => service.readImport(password: 'wrong', content: content),
      throwsA(isA<ExportPasswordException>()),
    );
  });

  test('rejects a file that is not an export', () async {
    expect(
      () => service.readImport(password: 'x', content: '{"hello":"world"}'),
      throwsA(isA<FormatException>()),
    );
  });
}
