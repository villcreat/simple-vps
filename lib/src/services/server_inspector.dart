import 'dart:convert';

import '../models/models.dart';
import 'ssh_service.dart';

/// A collected snapshot of a server's state ("passport").
class ServerPassport {
  ServerPassport({
    required this.osName,
    required this.kernel,
    required this.uptime,
    required this.cpuModel,
    required this.cpuCores,
    required this.loadAverage,
    required this.memory,
    required this.disk,
    required this.openPorts,
    required this.firewall,
    required this.dockerContainers,
    required this.nginxSites,
    required this.recentErrors,
    required this.collectedAt,
  });

  final String osName;
  final String kernel;
  final String uptime;
  final String cpuModel;
  final int cpuCores;
  final String loadAverage;
  final String memory;
  final String disk;
  final List<int> openPorts;
  final String firewall;
  final List<String> dockerContainers;
  final List<String> nginxSites;
  final List<String> recentErrors;
  final DateTime collectedAt;
}

/// Collects a [ServerPassport] over SSH using only read-only commands.
///
/// All probes are bundled into one command separated by `@@SECTION@@` markers,
/// so a passport needs a single round trip. Nothing here modifies the server.
class ServerInspector {
  ServerInspector(this.ssh);

  final SshService ssh;

  static const String command = 'echo "@@OS@@"; cat /etc/os-release 2>/dev/null; '
      'echo "@@KERNEL@@"; uname -r 2>/dev/null; '
      'echo "@@UPTIME@@"; uptime -p 2>/dev/null; '
      'echo "@@CPU@@"; grep -m1 "model name" /proc/cpuinfo 2>/dev/null; '
      'echo "@@CORES@@"; nproc 2>/dev/null; '
      'echo "@@LOAD@@"; cat /proc/loadavg 2>/dev/null; '
      'echo "@@MEM@@"; free -m 2>/dev/null; '
      'echo "@@DISK@@"; df -h / 2>/dev/null; '
      'echo "@@PORTS@@"; ss -lntu 2>/dev/null; '
      'echo "@@FW@@"; systemctl is-active ufw 2>/dev/null; '
      'echo "@@DOCKER@@"; docker ps --format "{{.Names}} {{.Status}}" 2>/dev/null; '
      'echo "@@NGINX@@"; ls /etc/nginx/sites-enabled 2>/dev/null; '
      'echo "@@ERRORS@@"; journalctl -p err -n 15 --no-pager 2>/dev/null; '
      'echo "@@END@@"';

  Future<ServerPassport> inspect(Server server) async {
    final session = await ssh.open(server);
    try {
      final raw = await _collect(session);
      final sections = _split(raw);
      return ServerPassport(
        osName: _osName(sections['OS'] ?? ''),
        kernel: (sections['KERNEL'] ?? '').trim(),
        uptime: (sections['UPTIME'] ?? '').trim(),
        cpuModel: _cpuModel(sections['CPU'] ?? ''),
        cpuCores: int.tryParse((sections['CORES'] ?? '').trim()) ?? 0,
        loadAverage: _load(sections['LOAD'] ?? ''),
        memory: _mem(sections['MEM'] ?? ''),
        disk: _disk(sections['DISK'] ?? ''),
        openPorts: _ports(sections['PORTS'] ?? ''),
        firewall: _firewall(sections['FW'] ?? ''),
        dockerContainers: _lines(sections['DOCKER'] ?? ''),
        nginxSites: _words(sections['NGINX'] ?? ''),
        recentErrors: _errors(sections['ERRORS'] ?? ''),
        collectedAt: DateTime.now(),
      );
    } finally {
      await session.close();
    }
  }

  Future<String> _collect(SshSession session) async {
    final buffer = StringBuffer();
    await for (final chunk in session.exec(command)) {
      if (!chunk.isDone && chunk.text != null) {
        buffer.write(chunk.text);
      }
    }
    return buffer.toString();
  }

  Map<String, String> _split(String raw) {
    final marker = RegExp(r'^@@(\w+)@@$');
    final result = <String, String>{};
    final buffer = <String>[];
    String? current;

    void flush() {
      if (current != null) {
        result[current] = buffer.join('\n');
      }
      buffer.clear();
    }

    for (final line in const LineSplitter().convert(raw)) {
      final match = marker.firstMatch(line.trim());
      if (match != null) {
        flush();
        current = match.group(1);
      } else {
        buffer.add(line);
      }
    }
    flush();
    return result;
  }

  String _osName(String section) {
    for (final line in const LineSplitter().convert(section)) {
      if (line.startsWith('PRETTY_NAME=')) {
        return line
            .substring('PRETTY_NAME='.length)
            .replaceAll('"', '')
            .trim();
      }
    }
    return 'Unknown';
  }

  String _cpuModel(String section) {
    final line = section.trim();
    final colon = line.indexOf(':');
    if (colon >= 0) {
      return line.substring(colon + 1).trim();
    }
    return line.isEmpty ? 'Unknown' : line;
  }

  String _load(String section) {
    final parts = section.trim().split(RegExp(r'\s+'));
    if (parts.length >= 3) {
      return '${parts[0]} ${parts[1]} ${parts[2]}';
    }
    return section.trim();
  }

  String _mem(String section) {
    for (final line in const LineSplitter().convert(section)) {
      if (line.startsWith('Mem:')) {
        final tokens = line.split(RegExp(r'\s+'));
        if (tokens.length >= 3) {
          return '${tokens[2]} / ${tokens[1]} MB';
        }
      }
    }
    return '—';
  }

  String _disk(String section) {
    final lines = const LineSplitter()
        .convert(section)
        .where((line) => line.trim().isNotEmpty)
        .toList();
    if (lines.length < 2) {
      return '—';
    }
    final tokens = lines.last.split(RegExp(r'\s+'));
    if (tokens.length >= 5) {
      return '${tokens[2]} / ${tokens[1]} (${tokens[4]})';
    }
    return '—';
  }

  List<int> _ports(String section) {
    final ports = <int>{};
    for (final line in const LineSplitter().convert(section)) {
      final trimmed = line.trim();
      if (trimmed.isEmpty ||
          trimmed.startsWith('Netid') ||
          trimmed.startsWith('State')) {
        continue;
      }
      for (final token in trimmed.split(RegExp(r'\s+'))) {
        final colon = token.lastIndexOf(':');
        if (colon <= 0 || colon == token.length - 1) {
          continue;
        }
        final port = int.tryParse(token.substring(colon + 1));
        if (port != null && port > 0) {
          ports.add(port);
          break; // The local address comes before the peer address.
        }
      }
    }
    return ports.toList()..sort();
  }

  String _firewall(String section) {
    final value = section.trim();
    return value.isEmpty ? 'unknown' : value;
  }

  List<String> _lines(String section) {
    return const LineSplitter()
        .convert(section)
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .take(20)
        .toList();
  }

  List<String> _words(String section) {
    return section
        .split(RegExp(r'\s+'))
        .map((word) => word.trim())
        .where((word) => word.isNotEmpty)
        .toList();
  }

  List<String> _errors(String section) {
    return const LineSplitter()
        .convert(section)
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty && !line.startsWith('-- '))
        .take(15)
        .toList();
  }
}
