import '../models/models.dart';
import 'command_safety.dart';

class ScenarioEngine {
  DryRunReport dryRun({
    required Scenario scenario,
    required Server server,
  }) {
    final warnings = <String>[];
    final files = <String>{};
    final ports = <int>{};

    for (final step in scenario.steps) {
      files.addAll(step.filesChanged);
      ports.addAll(step.portsOpened);

      if (step.dangerous || _looksDangerous(step.command)) {
        warnings.add('${step.title}: ${step.reason}');
      }
    }

    if (!scenario.supportedOs.contains(server.os)) {
      warnings.add(
        'Scenario ${scenario.name} does not support ${server.os.label}.',
      );
    }

    return DryRunReport(
      scenario: scenario,
      server: server,
      steps: scenario.steps,
      warnings: warnings,
      filesChanged: files.toList()..sort(),
      portsOpened: ports.toList()..sort(),
      backupsPlanned: const [
        '/var/lib/vps-simple/backups/<date>_3x-ui_install/metadata.json',
        '/var/lib/vps-simple/backups/<date>_3x-ui_install/firewall/',
        '/var/lib/vps-simple/backups/<date>_3x-ui_install/service-files/',
      ],
    );
  }

  bool _looksDangerous(String command) => CommandSafety.isDangerous(command);
}
