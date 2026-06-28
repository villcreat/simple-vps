import 'package:vps_simple/src/models/models.dart';
import 'package:vps_simple/src/services/ssh_service.dart';

/// In-memory [SshService] for tests. Records every executed command and lets a
/// test script which command should fail.
class FakeSshService implements SshService {
  FakeSshService({this.failIfContains, this.scripted = const {}});

  final List<String> commands = [];
  final String? failIfContains;

  /// Maps a command substring to the stdout it should produce. The first
  /// matching entry wins; commands with no match get a generic line.
  final Map<String, String> scripted;
  bool throwOnOpen = false;
  bool connectionOk = true;

  @override
  Future<SshConnectionResult> checkConnection(Server server) async {
    return SshConnectionResult(
      success: connectionOk,
      message: connectionOk ? 'ok' : 'unreachable',
    );
  }

  @override
  Stream<String> runCommand(Server server, String command) async* {
    commands.add(command);
    yield 'fake: $command';
  }

  @override
  Future<SshSession> open(Server server) async {
    if (throwOnOpen) {
      throw StateError('fake connection refused');
    }
    return _FakeSshSession(this);
  }

  final List<String> transfers = [];

  @override
  Future<void> uploadFile(
    Server server, {
    required String localPath,
    required String remotePath,
  }) async {
    transfers.add('up:$localPath->$remotePath');
  }

  @override
  Future<void> downloadFile(
    Server server, {
    required String remotePath,
    required String localPath,
  }) async {
    transfers.add('down:$remotePath->$localPath');
  }
}

class _FakeSshSession implements SshSession {
  _FakeSshSession(this._parent);

  final FakeSshService _parent;

  @override
  Stream<SshChunk> exec(String command) async* {
    _parent.commands.add(command);

    var output = 'output of: $command';
    for (final entry in _parent.scripted.entries) {
      if (command.contains(entry.key)) {
        output = entry.value;
        break;
      }
    }
    yield SshChunk.out(output);

    final fail = _parent.failIfContains != null &&
        command.contains(_parent.failIfContains!);
    yield SshChunk.done(fail ? 1 : 0);
  }

  @override
  Future<void> close() async {}
}
