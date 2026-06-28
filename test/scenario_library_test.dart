import 'package:flutter_test/flutter_test.dart';
import 'package:vps_simple/src/data/sample_data.dart';
import 'package:vps_simple/src/models/models.dart';
import 'package:vps_simple/src/services/execution/scenario_runner.dart';

import 'fake_ssh_service.dart';

Server _serverFor(Scenario scenario) {
  return Server(
    id: 'srv',
    name: 'Test VPS',
    host: '203.0.113.10',
    sshPort: 22,
    os: scenario.supportedOs.first,
    username: 'root',
    groupId: 'test',
    note: '',
    secretReference: 'srv',
    hostFingerprint: '',
    createdAt: DateTime(2026, 6, 26),
  );
}

void main() {
  test('every available catalog service maps to a scenario', () {
    for (final service in SampleData.catalog.where((s) => s.isAvailable)) {
      expect(
        SampleData.scenarioById(service.scenarioId),
        isNotNull,
        reason: service.id,
      );
    }
  });

  test('scenario ids are unique and each has steps and an OS', () {
    final ids = <String>{};
    for (final scenario in SampleData.scenarios) {
      expect(ids.add(scenario.id), isTrue, reason: 'duplicate ${scenario.id}');
      expect(scenario.supportedOs, isNotEmpty, reason: scenario.id);
      expect(scenario.steps, isNotEmpty, reason: scenario.id);
    }
  });

  test('every dangerous step defines a rollback command', () {
    for (final scenario in SampleData.scenarios) {
      for (final step in scenario.steps.where((s) => s.dangerous)) {
        expect(
          (step.rollbackCommand ?? '').isNotEmpty,
          isTrue,
          reason: '${scenario.id}/${step.id}',
        );
      }
    }
  });

  test('all scenarios run to success over a fake session', () async {
    for (final scenario in SampleData.scenarios) {
      final ssh = FakeSshService();
      final events = await ScenarioRunner(ssh)
          .run(
            scenario: scenario,
            server: _serverFor(scenario),
            confirmedDangerous: true,
            backupPath: '/tmp/backup',
          )
          .toList();

      final lastPhase = events
          .where((e) => e.type == ExecutionEventType.phase)
          .map((e) => e.phase!)
          .last;
      expect(lastPhase, RunPhase.success, reason: scenario.id);
    }
  });
}
