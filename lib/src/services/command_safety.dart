/// Heuristics for spotting potentially destructive shell commands.
///
/// Single source of truth shared by the scenario engine (dry-run warnings) and
/// the built-in terminal (per-command confirmation). False positives only add a
/// confirmation step, so the list errs on the side of caution.
class CommandSafety {
  CommandSafety._();

  static const List<String> _patterns = [
    'rm -rf',
    'rm -fr',
    'rm /etc',
    'mkfs',
    'dd if=',
    ':(){',
    'ufw allow',
    'ufw disable',
    'ufw --force',
    'iptables',
    'nft ',
    'systemctl stop ssh',
    'systemctl disable ssh',
    'service ssh stop',
    'passwd root',
    'chmod 777',
    'chown -r',
    'reboot',
    'shutdown',
    'halt',
    'poweroff',
    'init 0',
    'init 6',
    'userdel',
    'deluser',
    'docker system prune',
    'docker rm -f',
    'drop database',
    'drop table',
    '> /etc/',
    '>/etc/',
    '> /dev/sd',
  ];

  static bool isDangerous(String command) => reasons(command).isNotEmpty;

  /// Returns the matched danger patterns, for display in a confirmation.
  static List<String> reasons(String command) {
    final lower = command.toLowerCase();
    final found =
        _patterns.where((pattern) => lower.contains(pattern)).toList();

    final pipesToShell = (lower.contains('curl') || lower.contains('wget')) &&
        (lower.contains('| bash') ||
            lower.contains('|bash') ||
            lower.contains('| sh') ||
            lower.contains('|sh'));
    if (pipesToShell) {
      found.add('pipe download into a shell');
    }
    return found;
  }
}
