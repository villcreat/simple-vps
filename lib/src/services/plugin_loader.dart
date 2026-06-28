import 'dart:io';

import 'package:yaml/yaml.dart';

import '../models/models.dart';
import 'command_safety.dart';

/// Raised when a plugin manifest or installer recipe is malformed.
class PluginFormatException implements Exception {
  const PluginFormatException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// A loaded plugin: metadata plus a runnable [Scenario] for one OS.
class Plugin {
  Plugin({
    required this.id,
    required this.name,
    required this.version,
    required this.scenario,
  });

  final String id;
  final String name;
  final String version;
  final Scenario scenario;
}

/// Loads third-party plugins from a folder containing `plugin.yaml` plus the
/// per-OS installer recipes it references.
///
/// A loaded plugin produces an ordinary [Scenario], so it flows through the same
/// dry-run preview, micro-backup, confirmation, live log, and rollback as the
/// built-in catalog — nothing in a plugin runs without that review.
class PluginLoader {
  Future<Plugin> loadFromDirectory(String directory, ServerOs os) async {
    final manifest = await _readYaml('$directory/plugin.yaml');

    final entry = (manifest['entry'] as Map?)?.cast<String, dynamic>() ??
        const <String, dynamic>{};
    String? relative;
    for (final key in _entryKeys(os)) {
      final value = entry[key];
      if (value is String && value.isNotEmpty) {
        relative = value;
        break;
      }
    }
    if (relative == null) {
      throw PluginFormatException('Plugin has no installer for ${os.label}.');
    }

    final script = await _readYaml('$directory/$relative');
    final scenario = buildScenario(manifest: manifest, script: script);
    return Plugin(
      id: scenario.id,
      name: (manifest['name'] as String?) ?? scenario.name,
      version: manifest['version']?.toString() ?? '0.0.0',
      scenario: scenario,
    );
  }

  /// Pure builder used by [loadFromDirectory] and by tests. Validates the
  /// decoded manifest + installer and returns a runnable scenario.
  Scenario buildScenario({
    required Map<String, dynamic> manifest,
    required Map<String, dynamic> script,
  }) {
    final id = (manifest['id'] as String?) ?? (script['id'] as String?);
    final name = (manifest['name'] as String?) ?? (script['name'] as String?);
    if (id == null || id.isEmpty || name == null || name.isEmpty) {
      throw const PluginFormatException(
        'Plugin manifest needs an id and a name.',
      );
    }

    final supportedOs = _osList(script['os']);
    if (supportedOs.isEmpty) {
      throw const PluginFormatException(
        'Plugin installer lists no supported OS.',
      );
    }

    final rawSteps = script['steps'];
    if (rawSteps is! List || rawSteps.isEmpty) {
      throw const PluginFormatException('Plugin installer has no steps.');
    }
    final steps = rawSteps
        .whereType<Map>()
        .map((step) => _step(step.cast<String, dynamic>()))
        .toList();
    if (steps.isEmpty) {
      throw const PluginFormatException(
        'Plugin installer has no valid steps.',
      );
    }

    return Scenario(
      id: id,
      name: name,
      category: 'plugin',
      summary: (manifest['summary'] as String?) ??
          (script['summary'] as String?) ??
          'Plugin scenario.',
      supportedOs: supportedOs,
      steps: steps,
    );
  }

  ScenarioStep _step(Map<String, dynamic> map) {
    final command = (map['command'] as String?)?.trim();
    if (command == null || command.isEmpty) {
      throw const PluginFormatException('A plugin step is missing a command.');
    }
    final id = (map['id'] as String?) ?? 'step_${command.hashCode}';
    // A plugin author cannot hide danger: a command that looks destructive is
    // always treated as dangerous regardless of the declared flag.
    final dangerous =
        (map['dangerous'] as bool? ?? false) || CommandSafety.isDangerous(command);
    return ScenarioStep(
      id: id,
      title: (map['title'] as String?) ?? (map['id'] as String?) ?? 'Step',
      command: command,
      safe: map['safe'] as bool? ?? false,
      dangerous: dangerous,
      reason: (map['reason'] as String?) ?? '',
      filesChanged: _stringList(map['files_changed']),
      portsOpened: _intList(map['ports_opened']),
      rollbackCommand: map['rollback'] as String?,
    );
  }

  List<ServerOs> _osList(dynamic raw) {
    if (raw is! List) {
      return const [];
    }
    final result = <ServerOs>[];
    for (final item in raw) {
      final os = ServerOs.fromId(item.toString());
      if (os != ServerOs.unknown && !result.contains(os)) {
        result.add(os);
      }
    }
    return result;
  }

  List<String> _stringList(dynamic raw) {
    if (raw is! List) {
      return const [];
    }
    return raw.map((e) => e.toString()).toList();
  }

  List<int> _intList(dynamic raw) {
    if (raw is! List) {
      return const [];
    }
    final result = <int>[];
    for (final item in raw) {
      final value = item is int ? item : int.tryParse(item.toString());
      if (value != null) {
        result.add(value);
      }
    }
    return result;
  }

  List<String> _entryKeys(ServerOs os) => switch (os) {
        ServerOs.ubuntu => const ['ubuntu'],
        ServerOs.debian => const ['debian'],
        ServerOs.windowsServer => const ['windows_server', 'windows'],
        ServerOs.unknown => const [],
      };

  Future<Map<String, dynamic>> _readYaml(String path) async {
    final file = File(path);
    if (!await file.exists()) {
      throw PluginFormatException('File not found: $path');
    }
    final node = _normalize(loadYaml(await file.readAsString()));
    if (node is! Map<String, dynamic>) {
      throw PluginFormatException('Invalid YAML mapping in $path.');
    }
    return node;
  }

  dynamic _normalize(dynamic node) {
    if (node is YamlMap) {
      final map = <String, dynamic>{};
      node.forEach((key, value) => map[key.toString()] = _normalize(value));
      return map;
    }
    if (node is YamlList) {
      return node.map(_normalize).toList();
    }
    return node;
  }
}
