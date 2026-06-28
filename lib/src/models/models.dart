class Server {
  const Server({
    required this.id,
    required this.name,
    required this.host,
    required this.sshPort,
    required this.os,
    required this.username,
    required this.groupId,
    required this.note,
    required this.secretReference,
    required this.hostFingerprint,
    required this.createdAt,
    this.lastConnectedAt,
  });

  final String id;
  final String name;
  final String host;
  final int sshPort;
  final ServerOs os;
  final String username;
  final String groupId;
  final String note;
  final String secretReference;
  final String hostFingerprint;
  final DateTime createdAt;
  final DateTime? lastConnectedAt;

  Server copyWith({
    DateTime? lastConnectedAt,
    String? groupId,
    String? hostFingerprint,
  }) {
    return Server(
      id: id,
      name: name,
      host: host,
      sshPort: sshPort,
      os: os,
      username: username,
      groupId: groupId ?? this.groupId,
      note: note,
      secretReference: secretReference,
      hostFingerprint: hostFingerprint ?? this.hostFingerprint,
      createdAt: createdAt,
      lastConnectedAt: lastConnectedAt ?? this.lastConnectedAt,
    );
  }

  factory Server.fromJson(Map<String, dynamic> json) {
    return Server(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      host: json['host'] as String? ?? '',
      sshPort: json['sshPort'] as int? ?? 22,
      os: ServerOs.fromId(json['os'] as String?),
      username: json['username'] as String? ?? '',
      groupId: json['groupId'] as String? ?? 'personal',
      note: json['note'] as String? ?? '',
      secretReference: json['secretReference'] as String? ?? '',
      hostFingerprint: json['hostFingerprint'] as String? ?? '',
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
      lastConnectedAt:
          DateTime.tryParse(json['lastConnectedAt'] as String? ?? ''),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'host': host,
      'sshPort': sshPort,
      'os': os.id,
      'username': username,
      'groupId': groupId,
      'note': note,
      'secretReference': secretReference,
      'hostFingerprint': hostFingerprint,
      'createdAt': createdAt.toIso8601String(),
      'lastConnectedAt': lastConnectedAt?.toIso8601String(),
    };
  }
}

/// Live SSH reachability of a server (not persisted; reset on restart).
enum ServerStatus { unknown, checking, online, offline }

class ServerGroup {
  const ServerGroup({
    required this.id,
    required this.nameRu,
    required this.nameEn,
  });

  final String id;
  final String nameRu;
  final String nameEn;

  factory ServerGroup.fromJson(Map<String, dynamic> json) {
    final name = json['name'] as String?;
    return ServerGroup(
      id: json['id'] as String? ?? '',
      nameRu: json['nameRu'] as String? ?? name ?? '',
      nameEn: json['nameEn'] as String? ?? name ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {'id': id, 'nameRu': nameRu, 'nameEn': nameEn};
  }
}

enum ServerOs {
  ubuntu('ubuntu', 'Ubuntu'),
  debian('debian', 'Debian'),
  windowsServer('windows_server', 'Windows Server'),
  unknown('unknown', 'Unknown');

  const ServerOs(this.id, this.label);

  final String id;
  final String label;

  static ServerOs fromId(String? id) {
    return ServerOs.values.firstWhere(
      (os) => os.id == id,
      orElse: () => ServerOs.unknown,
    );
  }
}

class CatalogService {
  const CatalogService({
    required this.id,
    required this.name,
    required this.category,
    required this.descriptionRu,
    required this.descriptionEn,
    required this.scenarioId,
    required this.isAvailable,
  });

  final String id;
  final String name;
  final String category;
  final String descriptionRu;
  final String descriptionEn;
  final String scenarioId;
  final bool isAvailable;
}

class InstalledService {
  const InstalledService({
    required this.id,
    required this.serverId,
    required this.name,
    required this.version,
    required this.port,
    required this.status,
    required this.installPath,
    required this.installedAt,
    required this.category,
    required this.autoUpdateEnabled,
    this.login,
    this.secretReference,
    this.url,
    this.lastLog,
    this.controlCommands = const <String, String>{},
  });

  final String id;
  final String serverId;
  final String name;
  final String version;
  final int port;
  final String status;
  final String installPath;
  final DateTime installedAt;
  final String category;
  final bool autoUpdateEnabled;
  final String? login;
  final String? secretReference;
  final String? url;
  final String? lastLog;

  /// Management actions for this service: label -> shell command. Shown as
  /// editable, danger-checked buttons on the service card.
  final Map<String, String> controlCommands;

  factory InstalledService.fromJson(Map<String, dynamic> json) {
    return InstalledService(
      id: json['id'] as String? ?? '',
      serverId: json['serverId'] as String? ?? '',
      name: json['name'] as String? ?? '',
      version: json['version'] as String? ?? '',
      port: json['port'] as int? ?? 0,
      status: json['status'] as String? ?? 'unknown',
      installPath: json['installPath'] as String? ?? '',
      installedAt: DateTime.tryParse(json['installedAt'] as String? ?? '') ??
          DateTime.now(),
      category: json['category'] as String? ?? '',
      autoUpdateEnabled: json['autoUpdateEnabled'] as bool? ?? false,
      login: json['login'] as String?,
      secretReference: json['secretReference'] as String?,
      url: json['url'] as String?,
      lastLog: json['lastLog'] as String?,
      controlCommands: (json['controlCommands'] as Map?)
              ?.map((k, v) => MapEntry(k.toString(), v.toString())) ??
          const <String, String>{},
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'serverId': serverId,
      'name': name,
      'version': version,
      'port': port,
      'status': status,
      'installPath': installPath,
      'installedAt': installedAt.toIso8601String(),
      'category': category,
      'autoUpdateEnabled': autoUpdateEnabled,
      'login': login,
      'secretReference': secretReference,
      'url': url,
      'lastLog': lastLog,
      'controlCommands': controlCommands,
    };
  }
}

class InstallHistory {
  const InstallHistory({
    required this.id,
    required this.serverId,
    required this.scenarioId,
    required this.startedAt,
    required this.status,
    required this.commands,
    this.executedStepIds = const <String>[],
    this.serviceId,
    this.error,
    this.backupId,
    this.rollbackUsed = false,
  });

  final String id;
  final String serverId;
  final String? serviceId;
  final String scenarioId;
  final DateTime startedAt;
  final String status;
  final List<String> commands;
  final List<String> executedStepIds;
  final String? error;
  final String? backupId;
  final bool rollbackUsed;

  InstallHistory copyWith({String? status, bool? rollbackUsed}) {
    return InstallHistory(
      id: id,
      serverId: serverId,
      scenarioId: scenarioId,
      startedAt: startedAt,
      status: status ?? this.status,
      commands: commands,
      executedStepIds: executedStepIds,
      serviceId: serviceId,
      error: error,
      backupId: backupId,
      rollbackUsed: rollbackUsed ?? this.rollbackUsed,
    );
  }

  factory InstallHistory.fromJson(Map<String, dynamic> json) {
    return InstallHistory(
      id: json['id'] as String? ?? '',
      serverId: json['serverId'] as String? ?? '',
      scenarioId: json['scenarioId'] as String? ?? '',
      startedAt: DateTime.tryParse(json['startedAt'] as String? ?? '') ??
          DateTime.now(),
      status: json['status'] as String? ?? 'unknown',
      commands: (json['commands'] as List?)?.whereType<String>().toList() ??
          const <String>[],
      executedStepIds:
          (json['executedStepIds'] as List?)?.whereType<String>().toList() ??
              const <String>[],
      serviceId: json['serviceId'] as String?,
      error: json['error'] as String?,
      backupId: json['backupId'] as String?,
      rollbackUsed: json['rollbackUsed'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'serverId': serverId,
      'scenarioId': scenarioId,
      'startedAt': startedAt.toIso8601String(),
      'status': status,
      'commands': commands,
      'executedStepIds': executedStepIds,
      'serviceId': serviceId,
      'error': error,
      'backupId': backupId,
      'rollbackUsed': rollbackUsed,
    };
  }
}

class Backup {
  const Backup({
    required this.id,
    required this.serverId,
    required this.path,
    required this.type,
    required this.createdAt,
    required this.sizeBytes,
    required this.status,
    required this.canRollback,
    this.serviceId,
  });

  final String id;
  final String serverId;
  final String? serviceId;
  final String path;
  final String type;
  final DateTime createdAt;
  final int sizeBytes;
  final String status;
  final bool canRollback;

  factory Backup.fromJson(Map<String, dynamic> json) {
    return Backup(
      id: json['id'] as String? ?? '',
      serverId: json['serverId'] as String? ?? '',
      serviceId: json['serviceId'] as String?,
      path: json['path'] as String? ?? '',
      type: json['type'] as String? ?? '',
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
      sizeBytes: json['sizeBytes'] as int? ?? 0,
      status: json['status'] as String? ?? 'unknown',
      canRollback: json['canRollback'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'serverId': serverId,
      'serviceId': serviceId,
      'path': path,
      'type': type,
      'createdAt': createdAt.toIso8601String(),
      'sizeBytes': sizeBytes,
      'status': status,
      'canRollback': canRollback,
    };
  }
}

class SecurityEvent {
  const SecurityEvent({
    required this.id,
    required this.type,
    required this.title,
    required this.description,
    required this.createdAt,
    required this.severity,
    this.serverId,
  });

  final String id;
  final SecurityEventType type;
  final String title;
  final String description;
  final DateTime createdAt;
  final SecuritySeverity severity;
  final String? serverId;

  factory SecurityEvent.fromJson(Map<String, dynamic> json) {
    return SecurityEvent(
      id: json['id'] as String? ?? '',
      type: SecurityEventType.fromId(json['type'] as String?),
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
      severity: SecuritySeverity.fromId(json['severity'] as String?),
      serverId: json['serverId'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.id,
      'title': title,
      'description': description,
      'createdAt': createdAt.toIso8601String(),
      'severity': severity.id,
      'serverId': serverId,
    };
  }
}

enum SecurityEventType {
  appUnlocked('app_unlocked'),
  appLocked('app_locked'),
  serverAdded('server_added'),
  serverInspected('server_inspected'),
  serverDeleted('server_deleted'),
  dangerousCommandPreviewed('dangerous_command_previewed'),
  installConfirmed('install_confirmed'),
  rollbackRequested('rollback_requested'),
  secretViewed('secret_viewed'),
  exportStarted('export_started'),
  importStarted('import_started');

  const SecurityEventType(this.id);

  final String id;

  static SecurityEventType fromId(String? id) {
    return SecurityEventType.values.firstWhere(
      (type) => type.id == id,
      orElse: () => SecurityEventType.appUnlocked,
    );
  }
}

enum SecuritySeverity {
  info('info'),
  warning('warning'),
  danger('danger');

  const SecuritySeverity(this.id);

  final String id;

  static SecuritySeverity fromId(String? id) {
    return SecuritySeverity.values.firstWhere(
      (severity) => severity.id == id,
      orElse: () => SecuritySeverity.info,
    );
  }
}

class Scenario {
  const Scenario({
    required this.id,
    required this.name,
    required this.category,
    required this.summary,
    required this.supportedOs,
    required this.steps,
  });

  final String id;
  final String name;
  final String category;
  final String summary;
  final List<ServerOs> supportedOs;
  final List<ScenarioStep> steps;
}

class ScenarioStep {
  const ScenarioStep({
    required this.id,
    required this.title,
    required this.command,
    required this.safe,
    required this.dangerous,
    required this.reason,
    this.filesChanged = const <String>[],
    this.portsOpened = const <int>[],
    this.rollbackHint,
    this.rollbackCommand,
  });

  final String id;
  final String title;
  final String command;
  final bool safe;
  final bool dangerous;
  final String reason;
  final List<String> filesChanged;
  final List<int> portsOpened;

  /// Human-readable guidance shown in previews. Never executed automatically.
  final String? rollbackHint;

  /// Optional shell command run, in reverse order, when the user asks for a
  /// rollback of a completed install. Steps without one are skipped.
  final String? rollbackCommand;
}

class DryRunReport {
  const DryRunReport({
    required this.scenario,
    required this.server,
    required this.steps,
    required this.warnings,
    required this.filesChanged,
    required this.portsOpened,
    required this.backupsPlanned,
  });

  final Scenario scenario;
  final Server server;
  final List<ScenarioStep> steps;
  final List<String> warnings;
  final List<String> filesChanged;
  final List<int> portsOpened;
  final List<String> backupsPlanned;

  bool get hasDangerousActions => warnings.isNotEmpty;
}
