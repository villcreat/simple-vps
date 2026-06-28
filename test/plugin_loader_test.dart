import 'package:flutter_test/flutter_test.dart';
import 'package:vps_simple/src/models/models.dart';
import 'package:vps_simple/src/services/plugin_loader.dart';

void main() {
  final loader = PluginLoader();

  test('builds a scenario from a manifest and installer', () {
    final scenario = loader.buildScenario(
      manifest: {'id': 'demo', 'name': 'Demo', 'version': '1.0.0'},
      script: {
        'os': ['ubuntu'],
        'steps': [
          {'id': 'a', 'title': 'A', 'command': 'echo hi', 'safe': true},
          {
            'id': 'b',
            'title': 'B',
            'command': 'sudo ufw allow 80/tcp',
            'ports_opened': [80],
            'rollback': 'sudo ufw delete allow 80/tcp',
          },
        ],
      },
    );

    expect(scenario.id, 'demo');
    expect(scenario.category, 'plugin');
    expect(scenario.supportedOs, contains(ServerOs.ubuntu));
    expect(scenario.steps.length, 2);

    // "ufw allow" is detected as dangerous even though the flag was omitted.
    final danger = scenario.steps[1];
    expect(danger.dangerous, isTrue);
    expect(danger.portsOpened, contains(80));
    expect(danger.rollbackCommand, 'sudo ufw delete allow 80/tcp');
  });

  test('rejects malformed plugins', () {
    Map<String, dynamic> script(List steps, {List os = const ['ubuntu']}) =>
        {'os': os, 'steps': steps};

    // Missing id.
    expect(
      () => loader.buildScenario(
        manifest: {'name': 'X'},
        script: script([
          {'command': 'echo x'}
        ]),
      ),
      throwsA(isA<PluginFormatException>()),
    );
    // No steps.
    expect(
      () => loader.buildScenario(
        manifest: {'id': 'x', 'name': 'X'},
        script: script([]),
      ),
      throwsA(isA<PluginFormatException>()),
    );
    // No supported OS.
    expect(
      () => loader.buildScenario(
        manifest: {'id': 'x', 'name': 'X'},
        script: script([
          {'command': 'echo x'}
        ], os: const []),
      ),
      throwsA(isA<PluginFormatException>()),
    );
    // Step without a command.
    expect(
      () => loader.buildScenario(
        manifest: {'id': 'x', 'name': 'X'},
        script: script([
          {'title': 'no command'}
        ]),
      ),
      throwsA(isA<PluginFormatException>()),
    );
  });

  test('loads the bundled example plugin from disk', () async {
    const dir = 'plugins/examples/plugin-example-service';

    final ubuntu = await loader.loadFromDirectory(dir, ServerOs.ubuntu);
    expect(ubuntu.name, isNotEmpty);
    expect(ubuntu.version, '0.1.0');
    expect(ubuntu.scenario.supportedOs, contains(ServerOs.ubuntu));
    expect(ubuntu.scenario.steps, isNotEmpty);

    // The manifest uses the short entry key "windows" for windows_server.
    final windows = await loader.loadFromDirectory(dir, ServerOs.windowsServer);
    expect(windows.scenario.supportedOs, contains(ServerOs.windowsServer));
  });
}
