import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Resolves the per-user directory where VPS Simple keeps its local files.
///
/// Non-secret metadata and the encrypted secret vault live side by side in this
/// directory so they can be backed up or wiped together.
///
/// We rely on `path_provider` to pick a directory that is guaranteed to be
/// writable on every platform (the app sandbox on Android/iOS, `%APPDATA%` on
/// Windows, `~/.local/share` on Linux, Application Support on macOS). The old
/// approach of reading `APPDATA`/`HOME` from the environment only worked on
/// desktop: on Android none of those variables point to a writable location, so
/// the vault file could never be saved and the master password "reset" itself
/// on every launch.
class AppPaths {
  static Directory? _cached;

  static Future<Directory> baseDir() async {
    final cached = _cached;
    if (cached != null) {
      return cached;
    }

    Directory base;
    try {
      final support = await getApplicationSupportDirectory();
      base = Directory('${support.path}${Platform.pathSeparator}VPS Simple');
    } catch (_) {
      // Fallback for pure-Dart contexts where Flutter plugins are unavailable
      // (CLI tooling / tests run without binding initialisation).
      base = _envBaseDir();
    }

    await base.create(recursive: true);
    _cached = base;
    return base;
  }

  /// Environment-based fallback used only when `path_provider` is unavailable.
  static Directory _envBaseDir() {
    final appData = Platform.environment['APPDATA'];
    if (appData != null && appData.isNotEmpty) {
      return Directory('$appData${Platform.pathSeparator}VPS Simple');
    }

    final home =
        Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'];
    if (home != null && home.isNotEmpty) {
      return Directory('$home${Platform.pathSeparator}.vps_simple');
    }

    return Directory.current;
  }

  static Future<File> file(String name) async {
    final base = await baseDir();
    return File('${base.path}${Platform.pathSeparator}$name');
  }
}
