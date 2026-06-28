import 'package:flutter_test/flutter_test.dart';
import 'package:vps_simple/src/data/sample_data.dart';
import 'package:vps_simple/src/models/models.dart';
import 'package:vps_simple/src/services/execution/rollback_runner.dart';
import 'package:vps_simple/src/services/execution/scenario_runner.dart';

import 'fake_ssh_service.dart';

Server _server() {
  return Server(
    id: 'srv',
    name: 'Test VPS',
    host: '203.0.113.10',
    sshPort: 22,
    os: ServerOs.ubuntu,
    username: 'root',
    groupId: 'test',
    note: '',
    secretReference: 'srv',
    hostFingerprint: '',
    createdAt: DateTime(2026, 6, 26),
  );
}

void main() {
  test('runs rollback commands in reverse, skipping steps without one',
      () async {
    final ssh = FakeSshService();
    final events = await RollbackRunner(ssh)
        .run(
          scenario: SampleData.threeXUiScenario,
          server: _server(),
          executedStepIds: const [
            'check_os',
            'check_docker',
            'backup_firewall',
            'open_panel_port',
            'create_compose',
            'start_service',
          ],
        )
        .toList();

    final lastPhase = events
        .where((e) => e.type == ExecutionEventType.phase)
        .map((e) => e.phase!)
        .last;
    expect(lastPhase, RunPhase.success);

    // Only steps with a rollbackCommand run, newest first.
    expect(ssh.commands, [
      'cd /opt/3x-ui && sudo docker compose down',
      'sudo rm -rf /opt/3x-ui',
      'sudo ufw delete allow 2053/tcp',
    ]);
  });

  test('no rollback commands means nothing is executed', () async {
    final ssh = FakeSshService();
    final events = await RollbackRunner(ssh)
        .run(
          scenario: SampleData.threeXUiScenario,
          server: _server(),
          executedStepIds: const ['check_os', 'check_docker'],
        )
        .toList();

    final lastPhase = events
        .where((e) => e.type == ExecutionEventType.phase)
        .map((e) => e.phase!)
        .last;
    expect(lastPhase, RunPhase.success);
    expect(ssh.commands, isEmpty);
  });
}
