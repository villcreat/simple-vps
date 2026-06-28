import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import 'data/sample_data.dart';
import 'models/models.dart';
import 'services/crypto/export_service.dart';
import 'services/crypto/secret_vault.dart';
import 'services/execution/rollback_runner.dart';
import 'services/execution/scenario_runner.dart';
import 'services/local_json_store.dart';
import 'services/plugin_loader.dart';
import 'services/real_ssh_service.dart';
import 'services/scenario_engine.dart';
import 'services/server_inspector.dart';
import 'services/ssh_service.dart';

/// Reason the lock screen could not let the user in.
enum UnlockError { empty, wrongPassword }

class AppController extends ChangeNotifier {
  AppController({
    LocalJsonStore? store,
    ScenarioEngine? scenarioEngine,
    SshService? sshService,
    SecretVault? vault,
  })  : _store = store ?? LocalJsonStore(),
        scenarioEngine = scenarioEngine ?? ScenarioEngine(),
        vault = vault ?? SecretVault() {
    this.sshService = sshService ??
        RealSshService(
          resolveCredential: (server) =>
              this.vault.credentialFor(server.secretReference),
          onHostFingerprint: _recordFingerprint,
        );
  }

  final LocalJsonStore _store;
  final ScenarioEngine scenarioEngine;
  final SecretVault vault;
  late final SshService sshService;
  final ExportService _exportService = ExportService();
  final PluginLoader _pluginLoader = PluginLoader();

  ThemeMode themeMode = ThemeMode.system;
  Locale locale = const Locale('ru');
  bool isUnlocked = false;
  bool _vaultInitialized = false;
  UnlockError? unlockError;

  /// Idle minutes before the session auto-locks. 0 disables auto-lock.
  int autoLockMinutes = 10;
  DateTime _lastActivity = DateTime.now();
  Timer? _idleTimer;

  final List<ServerGroup> groups = List.of(SampleData.serverGroups);
  final List<CatalogService> catalog = List.of(SampleData.catalog);
  final List<InstalledService> installedServices = <InstalledService>[];
  final List<Backup> backups = <Backup>[];
  final List<Server> servers = <Server>[];
  final List<SecurityEvent> securityEvents = <SecurityEvent>[];
  final List<InstallHistory> installHistory = <InstallHistory>[];

  /// Plugins loaded this session (kept in memory only).
  final List<Plugin> plugins = <Plugin>[];

  // Live SSH reachability per server id (ephemeral; reset on restart).
  final Map<String, ServerStatus> _serverStatus = <String, ServerStatus>{};
  final Map<String, String> _serverStatusMessage = <String, String>{};

  // Context of the most recent run so the execution screen can offer rollback.
  Scenario? _lastScenario;
  Server? _lastServer;
  List<String> _lastExecutedStepIds = const <String>[];
  String? _lastHistoryId;
  String? _lastServiceId;

  Scenario get threeXUiScenario => SampleData.threeXUiScenario;

  /// Resolves a built-in scenario by id (used by the catalog → dry-run flow).
  Scenario? scenarioById(String id) => SampleData.scenarioById(id);

  /// Loads a plugin from a folder for the given OS and keeps it for this
  /// session. The plugin's scenario runs through the normal review flow.
  Future<Plugin> loadPlugin(String directory, ServerOs os) async {
    final plugin = await _pluginLoader.loadFromDirectory(directory, os);
    plugins.removeWhere((p) => p.id == plugin.id);
    plugins.insert(0, plugin);
    notifyListeners();
    return plugin;
  }

  /// True when no master password has been set yet (first launch).
  bool get needsSetup => !_vaultInitialized;

  Future<void> load() async {
    _vaultInitialized = await vault.isInitialized();

    final data = await _store.read();
    final rawSettings = data['settings'];
    final settings =
        rawSettings is Map<String, dynamic> ? rawSettings : <String, dynamic>{};

    final theme = settings['themeMode'] as String?;
    themeMode = switch (theme) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };

    final language = settings['languageCode'] as String?;
    if (language != null && (language == 'ru' || language == 'en')) {
      locale = Locale(language);
    }

    final lockMinutes = settings['autoLockMinutes'];
    if (lockMinutes is int && lockMinutes >= 0) {
      autoLockMinutes = lockMinutes;
    }

    _replaceAll(
      servers,
      data['servers'],
      Server.fromJson,
    );
    _replaceAll(
      securityEvents,
      data['securityEvents'],
      SecurityEvent.fromJson,
    );
    _replaceAll(
      installedServices,
      data['installedServices'],
      InstalledService.fromJson,
    );
    _replaceAll(
      backups,
      data['backups'],
      Backup.fromJson,
    );
    _replaceAll(
      installHistory,
      data['installHistory'],
      InstallHistory.fromJson,
    );

    final rawGroups = data['groups'];
    if (rawGroups is List) {
      for (final group in rawGroups
          .whereType<Map<String, dynamic>>()
          .map(ServerGroup.fromJson)) {
        if (!SampleData.isBuiltInGroup(group.id) &&
            !groups.any((g) => g.id == group.id)) {
          groups.add(group);
        }
      }
    }

    notifyListeners();
  }

  void _replaceAll<T>(
    List<T> target,
    Object? raw,
    T Function(Map<String, dynamic>) fromJson,
  ) {
    if (raw is! List) {
      return;
    }
    target
      ..clear()
      ..addAll(raw.whereType<Map<String, dynamic>>().map(fromJson));
  }

  /// Verifies the master password, or creates the vault on first launch.
  /// Returns true when the local session is unlocked.
  Future<bool> unlockOrSetup(String password) async {
    if (password.trim().isEmpty) {
      unlockError = UnlockError.empty;
      notifyListeners();
      return false;
    }

    bool success;
    if (_vaultInitialized) {
      success = await vault.unlock(password);
    } else {
      await vault.setup(password);
      _vaultInitialized = true;
      success = true;
    }

    if (!success) {
      unlockError = UnlockError.wrongPassword;
      notifyListeners();
      return false;
    }

    unlockError = null;
    isUnlocked = true;
    _lastActivity = DateTime.now();
    _startIdleWatch();
    await addSecurityEvent(
      _event(
        SecurityEventType.appUnlocked,
        'Application unlocked',
        'Master password accepted; the encrypted vault is open for this session.',
      ),
      persistImmediately: false,
    );
    await persist();
    notifyListeners();
    return true;
  }

  Future<void> lock() async {
    isUnlocked = false;
    _idleTimer?.cancel();
    vault.lock();
    await addSecurityEvent(
      _event(
        SecurityEventType.appLocked,
        'Application locked',
        'The local session was locked and the vault key was cleared from memory.',
      ),
      persistImmediately: false,
    );
    await persist();
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    themeMode = mode;
    await persist();
    notifyListeners();
  }

  Future<void> setLocale(Locale value) async {
    locale = value;
    await persist();
    notifyListeners();
  }

  // --- Auto-lock -----------------------------------------------------------

  /// Records user interaction so the idle watchdog does not lock during use.
  void registerActivity() {
    _lastActivity = DateTime.now();
  }

  Future<void> setAutoLockMinutes(int minutes) async {
    autoLockMinutes = minutes < 0 ? 0 : minutes;
    if (isUnlocked) {
      _lastActivity = DateTime.now();
      _startIdleWatch();
    }
    await persist();
    notifyListeners();
  }

  void _startIdleWatch() {
    _idleTimer?.cancel();
    if (autoLockMinutes <= 0) {
      return;
    }
    _idleTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      if (!isUnlocked) {
        return;
      }
      if (DateTime.now().difference(_lastActivity).inMinutes >=
          autoLockMinutes) {
        lock();
      }
    });
  }

  @override
  void dispose() {
    _idleTimer?.cancel();
    super.dispose();
  }

  // --- Encrypted export / import ------------------------------------------

  /// Writes an encrypted export file (servers + their vault secrets) protected
  /// by a separate [password].
  Future<void> exportToFile({
    required String password,
    required String path,
  }) async {
    final content = await _exportService.buildExport(
      password: password,
      servers: servers,
      secrets: vault.exportSecrets(),
    );
    final file = File(path);
    await file.parent.create(recursive: true);
    await file.writeAsString(content, flush: true);

    await addSecurityEvent(
      _event(
        SecurityEventType.exportStarted,
        'Servers exported',
        'Encrypted export written to $path.',
        severity: SecuritySeverity.warning,
      ),
      persistImmediately: false,
    );
    await persist();
    notifyListeners();
  }

  /// Reads an encrypted export file and merges new servers + secrets. Returns
  /// the number of servers added. Throws on a wrong password or bad file.
  Future<int> importFromFile({
    required String password,
    required String path,
  }) async {
    final content = await File(path).readAsString();
    final result =
        await _exportService.readImport(password: password, content: content);

    var added = 0;
    for (final server in result.servers) {
      if (servers.any((existing) => existing.id == server.id)) {
        continue;
      }
      servers.add(server);
      added++;
    }
    await vault.importSecrets(result.secrets);

    await addSecurityEvent(
      _event(
        SecurityEventType.importStarted,
        'Servers imported',
        '$added server(s) imported from $path.',
        severity: SecuritySeverity.warning,
      ),
      persistImmediately: false,
    );
    await persist();
    notifyListeners();
    return added;
  }

  Future<void> addServer(Server server) async {
    servers.add(server);
    await addSecurityEvent(
      _event(
        SecurityEventType.serverAdded,
        'Server added',
        '${server.name} (${server.host}) was added locally.',
        serverId: server.id,
      ),
      persistImmediately: false,
    );
    await persist();
    notifyListeners();
  }

  /// Replaces a server record in place (keeps its id and secret reference).
  Future<void> updateServer(Server server) async {
    final index = servers.indexWhere((s) => s.id == server.id);
    if (index == -1) {
      return;
    }
    servers[index] = server;
    await persist();
    notifyListeners();
  }

  /// Removes a server, its installed-service cards, its backups, and its secret.
  Future<void> deleteServer(Server server) async {
    servers.removeWhere((s) => s.id == server.id);
    installedServices.removeWhere((s) => s.serverId == server.id);
    backups.removeWhere((b) => b.serverId == server.id);
    if (vault.isUnlocked && server.secretReference.isNotEmpty) {
      await vault.remove(server.secretReference);
    }
    await addSecurityEvent(
      _event(
        SecurityEventType.serverDeleted,
        'Server deleted',
        '${server.name} (${server.host}) and its secret were removed.',
        severity: SecuritySeverity.warning,
        serverId: server.id,
      ),
      persistImmediately: false,
    );
    await persist();
    notifyListeners();
  }

  // --- Server groups -------------------------------------------------------

  /// User-created groups (everything that is not a built-in group).
  List<ServerGroup> get customGroups =>
      groups.where((g) => !SampleData.isBuiltInGroup(g.id)).toList();

  Future<void> addGroup(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      return;
    }
    groups.add(
      ServerGroup(id: _nextId('group'), nameRu: trimmed, nameEn: trimmed),
    );
    await persist();
    notifyListeners();
  }

  Future<void> renameGroup(String id, String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty || SampleData.isBuiltInGroup(id)) {
      return;
    }
    final index = groups.indexWhere((g) => g.id == id);
    if (index == -1) {
      return;
    }
    groups[index] = ServerGroup(id: id, nameRu: trimmed, nameEn: trimmed);
    await persist();
    notifyListeners();
  }

  /// Deletes a custom group and moves its servers back to "personal".
  Future<void> deleteGroup(String id) async {
    if (SampleData.isBuiltInGroup(id)) {
      return;
    }
    groups.removeWhere((g) => g.id == id);
    for (var i = 0; i < servers.length; i++) {
      if (servers[i].groupId == id) {
        servers[i] = servers[i].copyWith(groupId: 'personal');
      }
    }
    await persist();
    notifyListeners();
  }

  /// Stores a password secret in the encrypted vault under [reference].
  Future<void> setServerPassword(String reference, String password) async {
    if (!vault.isUnlocked || reference.isEmpty || password.isEmpty) {
      return;
    }
    await vault.putPassword(reference, password);
  }

  /// Stores a private-key secret in the encrypted vault under [reference].
  Future<void> setServerKey(
    String reference,
    String privateKeyPem, {
    String? passphrase,
  }) async {
    if (!vault.isUnlocked || reference.isEmpty || privateKeyPem.isEmpty) {
      return;
    }
    await vault.putKey(reference, privateKeyPem, passphrase: passphrase);
  }

  bool hasStoredSecret(Server server) =>
      server.secretReference.isNotEmpty && vault.hasSecret(server.secretReference);

  /// Returns the decrypted credential for a server, or null if none is stored
  /// or the vault is locked.
  SshCredential? credentialFor(Server server) =>
      vault.credentialFor(server.secretReference);

  /// Logs that the user revealed or copied a stored credential.
  Future<void> logSecretViewed(Server server) async {
    await addSecurityEvent(
      _event(
        SecurityEventType.secretViewed,
        'Credential viewed',
        'Revealed the stored credential for ${server.name}.',
        severity: SecuritySeverity.warning,
        serverId: server.id,
      ),
    );
  }

  Future<void> addSecurityEvent(
    SecurityEvent event, {
    bool persistImmediately = true,
  }) async {
    securityEvents.insert(0, event);
    if (persistImmediately) {
      await persist();
      notifyListeners();
    }
  }

  Server? findServer(String id) {
    for (final server in servers) {
      if (server.id == id) {
        return server;
      }
    }
    return null;
  }

  List<InstalledService> servicesForServer(String serverId) =>
      installedServices.where((s) => s.serverId == serverId).toList();

  /// Removes an installed-service card (does not touch the remote server).
  Future<void> removeInstalledService(String id) async {
    installedServices.removeWhere((s) => s.id == id);
    await persist();
    notifyListeners();
  }

  /// Records that a dangerous command was run from the built-in terminal.
  Future<void> logDangerousCommand(Server server, String command) async {
    await addSecurityEvent(
      _event(
        SecurityEventType.dangerousCommandPreviewed,
        'Dangerous command run',
        'On ${server.name}: $command',
        severity: SecuritySeverity.danger,
        serverId: server.id,
      ),
    );
  }

  ServerStatus serverStatus(String serverId) =>
      _serverStatus[serverId] ?? ServerStatus.unknown;

  String? serverStatusMessage(String serverId) => _serverStatusMessage[serverId];

  /// Probes a server over SSH and records online/offline plus last-connected.
  Future<void> checkServer(Server server) async {
    _serverStatus[server.id] = ServerStatus.checking;
    notifyListeners();

    final result = await sshService.checkConnection(server);
    _serverStatus[server.id] =
        result.success ? ServerStatus.online : ServerStatus.offline;
    _serverStatusMessage[server.id] = result.message;

    if (result.success) {
      final index = servers.indexWhere((s) => s.id == server.id);
      if (index != -1) {
        servers[index] =
            servers[index].copyWith(lastConnectedAt: DateTime.now());
      }
      await persist();
    }
    notifyListeners();
  }

  /// Checks every server's reachability in parallel.
  Future<void> checkAllServers() async {
    await Future.wait(servers.map(checkServer));
  }

  /// Trust-on-first-use: records a server's host-key fingerprint the first time
  /// it is seen, so later connections are pinned against it.
  Future<void> _recordFingerprint(Server server, String fingerprint) async {
    final index = servers.indexWhere((s) => s.id == server.id);
    if (index == -1 || servers[index].hostFingerprint.isNotEmpty) {
      return;
    }
    servers[index] = servers[index].copyWith(hostFingerprint: fingerprint);
    await persist();
    notifyListeners();
  }

  /// Uploads a local file to a server over SFTP.
  Future<void> uploadFile(
    Server server, {
    required String localPath,
    required String remotePath,
  }) =>
      sshService.uploadFile(
        server,
        localPath: localPath,
        remotePath: remotePath,
      );

  /// Downloads a remote file from a server over SFTP.
  Future<void> downloadFile(
    Server server, {
    required String remotePath,
    required String localPath,
  }) =>
      sshService.downloadFile(
        server,
        remotePath: remotePath,
        localPath: localPath,
      );

  /// Collects a live server passport over SSH (read-only) and logs the access.
  Future<ServerPassport> collectPassport(Server server) async {
    final passport = await ServerInspector(sshService).inspect(server);
    await addSecurityEvent(
      _event(
        SecurityEventType.serverInspected,
        'Server inspected',
        'Collected a passport for ${server.name} (${server.host}).',
        serverId: server.id,
      ),
    );
    return passport;
  }

  /// Runs a confirmed scenario and records the resulting service card, backup,
  /// and history entry. Streams [ExecutionEvent]s for the live log UI.
  Stream<ExecutionEvent> runScenario({
    required Scenario scenario,
    required Server server,
    required bool confirmedDangerous,
  }) async* {
    final backupPath =
        '/var/lib/vps-simple/backups/${_stamp()}_${scenario.id}';
    final runner = ScenarioRunner(sshService);

    await addSecurityEvent(
      _event(
        SecurityEventType.installConfirmed,
        'Installation started',
        'User confirmed ${scenario.name} on ${server.name}.',
        severity: SecuritySeverity.warning,
        serverId: server.id,
      ),
      persistImmediately: false,
    );

    final executed = <String>[];
    var phase = RunPhase.aborted;

    await for (final event in runner.run(
      scenario: scenario,
      server: server,
      confirmedDangerous: confirmedDangerous,
      backupPath: backupPath,
    )) {
      if (event.type == ExecutionEventType.phase && event.phase != null) {
        phase = event.phase!;
      }
      if (event.type == ExecutionEventType.step &&
          event.status == StepStatus.success &&
          event.stepId != null) {
        executed.add(event.stepId!);
      }
      yield event;
    }

    await _finishRun(
      scenario: scenario,
      server: server,
      phase: phase,
      executedStepIds: executed,
      backupPath: backupPath,
    );
  }

  Future<void> _finishRun({
    required Scenario scenario,
    required Server server,
    required RunPhase phase,
    required List<String> executedStepIds,
    required String backupPath,
  }) async {
    final succeeded = phase == RunPhase.success;
    final touchesFiles =
        scenario.steps.any((step) => step.filesChanged.isNotEmpty);

    String? backupId;
    if (touchesFiles && executedStepIds.isNotEmpty) {
      backupId = _nextId('backup');
      backups.insert(
        0,
        Backup(
          id: backupId,
          serverId: server.id,
          path: backupPath,
          type: 'pre-install',
          createdAt: DateTime.now(),
          sizeBytes: 0,
          status: 'available',
          canRollback: true,
        ),
      );
    }

    String? serviceId;
    if (succeeded) {
      serviceId = _nextId('service');
      final port = _firstPort(scenario);
      installedServices.insert(
        0,
        InstalledService(
          id: serviceId,
          serverId: server.id,
          name: scenario.name,
          version: 'latest',
          port: port,
          status: 'running',
          installPath: _installPath(scenario),
          installedAt: DateTime.now(),
          category: scenario.category,
          autoUpdateEnabled: false,
          url: port > 0 ? 'http://${server.host}:$port' : null,
          controlCommands: _controlCommandsFor(scenario, _installPath(scenario)),
        ),
      );
    }

    final historyId = _nextId('history');
    installHistory.insert(
      0,
      InstallHistory(
        id: historyId,
        serverId: server.id,
        serviceId: serviceId,
        scenarioId: scenario.id,
        startedAt: DateTime.now(),
        status: succeeded ? 'success' : 'failed',
        commands: [
          for (final step in scenario.steps)
            if (executedStepIds.contains(step.id)) step.command,
        ],
        executedStepIds: executedStepIds,
        backupId: backupId,
      ),
    );

    _lastScenario = scenario;
    _lastServer = server;
    _lastExecutedStepIds = executedStepIds;
    _lastHistoryId = historyId;
    _lastServiceId = serviceId;

    await addSecurityEvent(
      _event(
        SecurityEventType.installConfirmed,
        succeeded ? 'Installation finished' : 'Installation failed',
        succeeded
            ? '${scenario.name} installed on ${server.name}.'
            : '${scenario.name} stopped on ${server.name}. Rollback is available.',
        severity: succeeded ? SecuritySeverity.info : SecuritySeverity.danger,
        serverId: server.id,
      ),
      persistImmediately: false,
    );
    await persist();
    notifyListeners();
  }

  bool get canRollbackLastRun =>
      _lastScenario != null &&
      _lastServer != null &&
      _lastExecutedStepIds.isNotEmpty;

  /// Reverts the most recent run by executing each step's rollback command in
  /// reverse. Triggered only by an explicit user action.
  Stream<ExecutionEvent> rollbackLastRun() async* {
    final scenario = _lastScenario;
    final server = _lastServer;
    if (scenario == null || server == null) {
      yield ExecutionEvent.errorLine('There is no recent run to roll back.');
      yield ExecutionEvent.phase(RunPhase.aborted);
      return;
    }

    await addSecurityEvent(
      _event(
        SecurityEventType.rollbackRequested,
        'Rollback requested',
        'User started rollback of ${scenario.name} on ${server.name}.',
        severity: SecuritySeverity.warning,
        serverId: server.id,
      ),
      persistImmediately: false,
    );

    final runner = RollbackRunner(sshService);
    var phase = RunPhase.aborted;
    await for (final event in runner.run(
      scenario: scenario,
      server: server,
      executedStepIds: _lastExecutedStepIds,
    )) {
      if (event.type == ExecutionEventType.phase && event.phase != null) {
        phase = event.phase!;
      }
      yield event;
    }

    _applyRollbackResult(succeeded: phase == RunPhase.success);
    await persist();
    notifyListeners();
  }

  void _applyRollbackResult({required bool succeeded}) {
    final historyId = _lastHistoryId;
    if (historyId != null) {
      final index = installHistory.indexWhere((h) => h.id == historyId);
      if (index != -1) {
        installHistory[index] = installHistory[index].copyWith(
          rollbackUsed: true,
          status: succeeded ? 'rolled_back' : 'rollback_failed',
        );
      }
    }

    if (succeeded) {
      final serviceId = _lastServiceId;
      if (serviceId != null) {
        installedServices.removeWhere((s) => s.id == serviceId);
      }
      _lastScenario = null;
      _lastServer = null;
      _lastExecutedStepIds = const <String>[];
      _lastServiceId = null;
    }
  }

  Future<void> persist() async {
    await _store.write({
      'settings': {
        'themeMode': themeMode.name,
        'languageCode': locale.languageCode,
        'autoLockMinutes': autoLockMinutes,
      },
      'servers': servers.map((server) => server.toJson()).toList(),
      'securityEvents': securityEvents.map((event) => event.toJson()).toList(),
      'installedServices':
          installedServices.map((service) => service.toJson()).toList(),
      'backups': backups.map((backup) => backup.toJson()).toList(),
      'installHistory': installHistory.map((entry) => entry.toJson()).toList(),
      'groups': customGroups.map((group) => group.toJson()).toList(),
    });
  }

  String nextServerId() => _nextId('server');

  SecurityEvent _event(
    SecurityEventType type,
    String title,
    String description, {
    SecuritySeverity severity = SecuritySeverity.info,
    String? serverId,
  }) {
    return SecurityEvent(
      id: _nextId('event'),
      type: type,
      title: title,
      description: description,
      createdAt: DateTime.now(),
      severity: severity,
      serverId: serverId,
    );
  }

  int _firstPort(Scenario scenario) {
    for (final step in scenario.steps) {
      if (step.portsOpened.isNotEmpty) {
        return step.portsOpened.first;
      }
    }
    return 0;
  }

  /// Derives standard management commands for an installed service from the
  /// shape of its scenario (Docker Compose, systemd, or Nginx).
  Map<String, String> _controlCommandsFor(Scenario scenario, String installPath) {
    final commands = scenario.steps.map((s) => s.command).join('\n');
    if (commands.contains('docker compose')) {
      return {
        'Restart': 'cd $installPath && sudo docker compose restart',
        'Stop': 'cd $installPath && sudo docker compose down',
        'Start': 'cd $installPath && sudo docker compose up -d',
        'Update':
            'cd $installPath && sudo docker compose pull && sudo docker compose up -d',
        'Logs': 'cd $installPath && sudo docker compose logs --tail 100',
      };
    }
    final enable = RegExp(r'systemctl enable --now (\S+)').firstMatch(commands);
    if (enable != null) {
      final service = enable.group(1)!;
      return {
        'Restart': 'sudo systemctl restart $service',
        'Stop': 'sudo systemctl stop $service',
        'Start': 'sudo systemctl start $service',
        'Status': 'sudo systemctl status $service --no-pager',
        'Logs': 'sudo journalctl -u $service -n 100 --no-pager',
      };
    }
    if (commands.contains('nginx')) {
      return {
        'Reload Nginx': 'sudo nginx -t && sudo systemctl reload nginx',
        'Logs': 'sudo tail -n 100 /var/log/nginx/access.log',
      };
    }
    return const <String, String>{};
  }

  String _installPath(Scenario scenario) {
    for (final step in scenario.steps) {
      if (step.filesChanged.isNotEmpty) {
        final file = step.filesChanged.first;
        final slash = file.lastIndexOf('/');
        return slash > 0 ? file.substring(0, slash) : file;
      }
    }
    return '/opt/${scenario.id}';
  }

  String _stamp() {
    final now = DateTime.now();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${now.year}-${two(now.month)}-${two(now.day)}_'
        '${two(now.hour)}${two(now.minute)}${two(now.second)}';
  }

  String _nextId(String prefix) {
    return '${prefix}_${DateTime.now().microsecondsSinceEpoch}';
  }
}
