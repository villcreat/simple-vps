import '../models/models.dart';

/// Boundary for all SSH access.
///
/// The app never runs shell commands directly. Screens and the scenario engine
/// talk to this interface so that preview, confirmation, logging, and rollback
/// stay in one controlled flow. [StubSshService] keeps the UI safe when no real
/// transport is wired in; [RealSshService] provides the production client.
abstract class SshService {
  /// Connects once, runs a lightweight probe, and reports reachability.
  Future<SshConnectionResult> checkConnection(Server server);

  /// One-shot command used by the built-in terminal. Streams output lines.
  Stream<String> runCommand(Server server, String command);

  /// Opens a persistent session so a whole scenario can run over one
  /// connection. The caller must [SshSession.close] it when finished.
  Future<SshSession> open(Server server);

  /// Uploads a local file to the server over SFTP.
  Future<void> uploadFile(
    Server server, {
    required String localPath,
    required String remotePath,
  });

  /// Downloads a remote file to a local path over SFTP.
  Future<void> downloadFile(
    Server server, {
    required String remotePath,
    required String localPath,
  });
}

/// A persistent SSH connection that can run several commands in sequence.
abstract class SshSession {
  /// Runs [command] and streams its output as [SshChunk]s. The stream emits a
  /// final [SshChunk.done] carrying the exit code, then closes.
  Stream<SshChunk> exec(String command);

  Future<void> close();
}

/// A piece of command output, or the terminal exit-code marker.
class SshChunk {
  const SshChunk.out(this.text)
      : isError = false,
        exitCode = null;

  const SshChunk.err(this.text)
      : isError = true,
        exitCode = null;

  const SshChunk.done(this.exitCode)
      : text = null,
        isError = false;

  final String? text;
  final bool isError;
  final int? exitCode;

  bool get isDone => exitCode != null;
}

class SshConnectionResult {
  const SshConnectionResult({
    required this.success,
    required this.message,
  });

  final bool success;
  final String message;
}

/// A credential resolved from the encrypted vault, never persisted in plain
/// text alongside server metadata.
class SshCredential {
  const SshCredential.password(this.password)
      : privateKeyPem = null,
        passphrase = null;

  const SshCredential.key(this.privateKeyPem, {this.passphrase})
      : password = null;

  final String? password;
  final String? privateKeyPem;
  final String? passphrase;

  bool get isKey => privateKeyPem != null && privateKeyPem!.isNotEmpty;
}

/// Safe default: never touches the network. Used in tests and as a fallback
/// when SSH is intentionally disabled.
class StubSshService implements SshService {
  @override
  Future<SshConnectionResult> checkConnection(Server server) async {
    await Future<void>.delayed(const Duration(milliseconds: 250));
    return const SshConnectionResult(
      success: false,
      message: 'SSH core is disabled in this build (StubSshService).',
    );
  }

  @override
  Stream<String> runCommand(Server server, String command) async* {
    yield 'Dry-run only: no command was executed on ${server.host}.';
    yield 'Command preview: $command';
  }

  @override
  Future<SshSession> open(Server server) async {
    throw UnsupportedError('StubSshService cannot open real SSH sessions.');
  }

  @override
  Future<void> uploadFile(
    Server server, {
    required String localPath,
    required String remotePath,
  }) async {
    throw UnsupportedError('StubSshService cannot transfer files.');
  }

  @override
  Future<void> downloadFile(
    Server server, {
    required String remotePath,
    required String localPath,
  }) async {
    throw UnsupportedError('StubSshService cannot transfer files.');
  }
}
