import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dartssh2/dartssh2.dart';

import '../models/models.dart';
import 'ssh_service.dart';

/// Resolves the credential for a server from the unlocked vault.
typedef CredentialResolver = SshCredential? Function(Server server);

/// Called when a host-key fingerprint is observed, for trust-on-first-use.
typedef HostFingerprintHandler = void Function(Server server, String fingerprint);

/// Decides whether to accept a host key given the pinned fingerprint.
///
/// An empty [pinned] value means trust-on-first-use (accept and let the caller
/// record it). A non-empty pinned value must match [observed] exactly, which is
/// what protects against a man-in-the-middle on later connections.
bool acceptHostFingerprint(String pinned, String observed) {
  final expected = pinned.trim();
  return expected.isEmpty || expected == observed.trim();
}

/// Production SSH client backed by the pure-Dart `dartssh2` package, so the
/// same code path works on desktop and Android.
///
/// Credentials are pulled from the encrypted vault through [resolveCredential]
/// at connect time and are never stored on this object.
class RealSshService implements SshService {
  RealSshService({required this.resolveCredential, this.onHostFingerprint});

  final CredentialResolver resolveCredential;
  final HostFingerprintHandler? onHostFingerprint;

  @override
  Future<SshConnectionResult> checkConnection(Server server) async {
    SSHClient? client;
    try {
      client = await _connect(server);
      final output = await client.run('uname -a || ver');
      final text = utf8.decode(output, allowMalformed: true).trim();
      return SshConnectionResult(
        success: true,
        message: text.isEmpty ? 'Connected.' : text,
      );
    } catch (error) {
      return SshConnectionResult(
        success: false,
        message: 'Connection failed: $error',
      );
    } finally {
      client?.close();
    }
  }

  @override
  Stream<String> runCommand(Server server, String command) async* {
    final client = await _connect(server);
    try {
      await for (final chunk in _exec(client, command)) {
        if (!chunk.isDone && chunk.text != null) {
          yield chunk.text!;
        }
      }
    } finally {
      client.close();
    }
  }

  @override
  Future<SshSession> open(Server server) async {
    final client = await _connect(server);
    return _RealSshSession(client);
  }

  @override
  Future<void> uploadFile(
    Server server, {
    required String localPath,
    required String remotePath,
  }) async {
    final bytes = await File(localPath).readAsBytes();
    final client = await _connect(server);
    try {
      final sftp = await client.sftp();
      final file = await sftp.open(
        remotePath,
        mode: SftpFileOpenMode.create |
            SftpFileOpenMode.write |
            SftpFileOpenMode.truncate,
      );
      try {
        await file.writeBytes(bytes);
      } finally {
        await file.close();
      }
    } finally {
      client.close();
    }
  }

  @override
  Future<void> downloadFile(
    Server server, {
    required String remotePath,
    required String localPath,
  }) async {
    final client = await _connect(server);
    try {
      final sftp = await client.sftp();
      final file = await sftp.open(remotePath);
      final bytes = await file.readBytes();
      await file.close();
      await File(localPath).writeAsBytes(bytes);
    } finally {
      client.close();
    }
  }

  Future<SSHClient> _connect(Server server) async {
    final credential = resolveCredential(server);
    if (credential == null) {
      throw StateError(
        'No stored credential for "${server.name}". Add a password or key first.',
      );
    }

    final socket = await SSHSocket.connect(
      server.host,
      server.sshPort,
      timeout: const Duration(seconds: 15),
    );

    final identities = <SSHKeyPair>[];
    if (credential.isKey) {
      identities.addAll(
        SSHKeyPair.fromPem(credential.privateKeyPem!, credential.passphrase),
      );
    }

    final client = SSHClient(
      socket,
      username: server.username,
      onPasswordRequest: () => credential.password ?? '',
      identities: identities.isEmpty ? null : identities,
      onVerifyHostKey: (_, fingerprintBytes) {
        final observed = utf8.decode(fingerprintBytes, allowMalformed: true);
        final accepted = acceptHostFingerprint(server.hostFingerprint, observed);
        // Trust on first use: record the fingerprint so later connects pin it.
        if (accepted && server.hostFingerprint.trim().isEmpty) {
          onHostFingerprint?.call(server, observed);
        }
        return accepted;
      },
    );

    await client.authenticated;
    return client;
  }
}

class _RealSshSession implements SshSession {
  _RealSshSession(this._client);

  final SSHClient _client;

  @override
  Stream<SshChunk> exec(String command) => _exec(_client, command);

  @override
  Future<void> close() async {
    _client.close();
    await _client.done;
  }
}

/// Runs [command] over [client], merging stdout and stderr into a single
/// [SshChunk] stream and finishing with the exit code.
Stream<SshChunk> _exec(SSHClient client, String command) async* {
  final session = await client.execute(command);
  final controller = StreamController<SshChunk>();
  var openStreams = 2;

  void onStreamDone() {
    openStreams--;
    if (openStreams == 0 && !controller.isClosed) {
      controller.close();
    }
  }

  session.stdout.listen(
    (data) => controller.add(
      SshChunk.out(utf8.decode(data, allowMalformed: true)),
    ),
    onError: (Object error) => controller.add(SshChunk.err(error.toString())),
    onDone: onStreamDone,
  );
  session.stderr.listen(
    (data) => controller.add(
      SshChunk.err(utf8.decode(data, allowMalformed: true)),
    ),
    onError: (Object error) => controller.add(SshChunk.err(error.toString())),
    onDone: onStreamDone,
  );

  yield* controller.stream;
  await session.done;
  yield SshChunk.done(session.exitCode ?? 0);
}
