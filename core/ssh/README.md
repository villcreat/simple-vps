# SSH Core

Implemented in `lib/src/services/ssh_service.dart` (boundary + `StubSshService`)
and `lib/src/services/real_ssh_service.dart` (`RealSshService`, backed by the
pure-Dart `dartssh2` client). Supports password and private-key auth, one-shot
commands, and a streaming `SshSession` used by the scenario runner and the
built-in terminal (`lib/src/screens/ssh_terminal_screen.dart`).

TODO: pin SSH host-key fingerprints on connect; add file upload/download; add a
PTY/interactive shell so terminal commands share a persistent working directory.
