import 'package:flutter_test/flutter_test.dart';
import 'package:vps_simple/src/data/sample_data.dart';
import 'package:vps_simple/src/models/models.dart';
import 'package:vps_simple/src/services/scenario_engine.dart';

void main() {
  test('dry-run reports dangerous 3X-UI steps without executing commands', () {
    final server = Server(
      id: 'server_test',
      name: 'Test VPS',
      host: '203.0.113.10',
      sshPort: 22,
      os: ServerOs.ubuntu,
      username: 'root',
      groupId: 'test',
      note: '',
      secretReference: '',
      hostFingerprint: '',
      createdAt: DateTime(2026, 6, 26),
    );

    final report = ScenarioEngine().dryRun(
      scenario: SampleData.threeXUiScenario,
      server: server,
    );

    expect(report.hasDangerousActions, isTrue);
    expect(report.portsOpened, contains(2053));
    expect(report.filesChanged, contains('/opt/3x-ui/docker-compose.yml'));
  });
}
