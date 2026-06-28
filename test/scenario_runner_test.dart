import 'package:flutter_test/flutter_test.dart';
import 'package:vps_simple/src/data/sample_data.dart';
import 'package:vps_simple/src/models/models.dart';
import 'package:vps_simple/src/services/execution/scenario_runner.dart';

import 'fake_ssh_service.dart';

Server _server({ServerOs os = ServerOs.ubuntu}) {
  return Server(
    id: 'srv',
    name: 'Test VPS',
    host: '203.0.113.10',
    sshPort: 22,
    os: os,
    username: 'root',
    groupId: 'test',
    note: '',
    secretReference: 'srv',
    hostFingerprint: '',
    createdAt: DateTime(2026, 6, 26),
  );
}

Map<String, StepStatus> _finalStatuses(List<ExecutionEvent> events) {
  final byId = <String, StepStatus>{};
  for (final event in events) {
    if (event.type == ExecutionEventType.step && event.stepId != null) {
      byId[event.stepId!] = event.status!;
    }
  }
  return byId;
}

RunPhase _lastPhase(List<ExecutionEvent> events) {
  return events
      .where((e) => e.type == ExecutionEventType.phase)
      .map((e) => e.phase!)
      .last;
}

void main() {
  test('runs every step over one session when confirmed', () async {
    final ssh = FakeSshService();
    final events = await ScenarioRunner(ssh)
        .run(
          scenario: SampleData.threeXUiScenario,
          server: _server(),
          confirmedDangerous: true,
          backupPath: '/var/lib/vps-simple/backups/test_3x-ui',
        )
        .toList();

    expect(_lastPhase(events), RunPhase.success);

    final statuses = _finalStatuses(events);
    for (final step in SampleData.threeXUiScenario.steps) {
      expect(statuses[step.id], StepStatus.success, reason: step.id);
    }

    // Backup phase ran before the dangerous steps.
    expect(ssh.commands.any((c) => c.contains('mkdir -p')), isTrue);
    expect(ssh.commands, contains('sudo ufw allow 2053/tcp'));
  });

  test('aborts dangerous scenario without confirmation', () async {
    final ssh = FakeSshService();
    final events = await ScenarioRunner(ssh)
        .run(
          scenario: SampleData.threeXUiScenario,
          server: _server(),
          confirmedDangerous: false,
          backupPath: '/tmp/x',
        )
        .toList();

    expect(_lastPhase(events), RunPhase.aborted);
    expect(ssh.commands, isEmpty);
  });

  test('stops at the first failing step', () async {
    final ssh = FakeSshService(failIfContains: 'ufw allow');
    final events = await ScenarioRunner(ssh)
        .run(
          scenario: SampleData.threeXUiScenario,
          server: _server(),
          confirmedDangerous: true,
          backupPath: '/tmp/x',
        )
        .toList();

    expect(_lastPhase(events), RunPhase.failed);
    expect(_finalStatuses(events)['open_panel_port'], StepStatus.failed);
    // The step after the failure must not run.
    expect(ssh.commands.any((c) => c.contains('tee /opt/3x-ui')), isFalse);
  });

  test('aborts when the server OS is unsupported', () async {
    final ssh = FakeSshService();
    final events = await ScenarioRunner(ssh)
        .run(
          scenario: SampleData.threeXUiScenario,
          server: _server(os: ServerOs.windowsServer),
          confirmedDangerous: true,
          backupPath: '/tmp/x',
        )
        .toList();

    expect(_lastPhase(events), RunPhase.aborted);
    expect(ssh.commands, isEmpty);
  });
}
