import 'package:flutter_test/flutter_test.dart';
import 'package:vps_simple/src/services/command_safety.dart';

void main() {
  test('flags destructive commands', () {
    const dangerous = [
      'rm -rf /',
      'sudo ufw allow 80/tcp',
      'curl https://example.sh | bash',
      'wget -O- https://example | sh',
      'sudo reboot',
      'echo x > /etc/hosts',
      'iptables -F',
      'passwd root',
      'chmod 777 /var/www',
    ];
    for (final command in dangerous) {
      expect(CommandSafety.isDangerous(command), isTrue, reason: command);
    }
  });

  test('allows ordinary commands', () {
    const safe = [
      'ls -la',
      'cat /etc/os-release',
      'systemctl restart nginx',
      'docker ps',
      'df -h',
      'uname -a',
      'tail -n 100 /var/log/syslog',
    ];
    for (final command in safe) {
      expect(CommandSafety.isDangerous(command), isFalse, reason: command);
    }
  });

  test('reasons lists the matched patterns', () {
    expect(CommandSafety.reasons('sudo rm -rf /var'), contains('rm -rf'));
    expect(CommandSafety.reasons('ls'), isEmpty);
  });
}
