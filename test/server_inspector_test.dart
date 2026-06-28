import 'package:flutter_test/flutter_test.dart';
import 'package:vps_simple/src/models/models.dart';
import 'package:vps_simple/src/services/server_inspector.dart';

import 'fake_ssh_service.dart';

const _fakeOutput = '''
@@OS@@
PRETTY_NAME="Ubuntu 22.04.3 LTS"
NAME="Ubuntu"
@@KERNEL@@
5.15.0-89-generic
@@UPTIME@@
up 3 days, 2 hours
@@CPU@@
model name	: Intel(R) Xeon(R) CPU E5-2680
@@CORES@@
4
@@LOAD@@
0.15 0.10 0.05 1/200 1234
@@MEM@@
              total        used        free      shared  buff/cache   available
Mem:           1987         512         900          10         574        1300
Swap:          1023           0        1023
@@DISK@@
Filesystem      Size  Used Avail Use% Mounted on
/dev/vda1        25G  8.1G   16G  34% /
@@PORTS@@
Netid State  Recv-Q Send-Q Local Address:Port Peer Address:Port
tcp   LISTEN 0      128          0.0.0.0:22         0.0.0.0:*
tcp   LISTEN 0      128          0.0.0.0:80         0.0.0.0:*
@@FW@@
active
@@DOCKER@@
3x-ui Up 2 hours
@@NGINX@@
landing
@@ERRORS@@
-- Logs begin at Tue --
nginx: connection reset
@@END@@
''';

Server _server() {
  return Server(
    id: 'srv',
    name: 'Test VPS',
    host: '203.0.113.10',
    sshPort: 22,
    os: ServerOs.ubuntu,
    username: 'root',
    groupId: 'test',
    note: '',
    secretReference: 'srv',
    hostFingerprint: '',
    createdAt: DateTime(2026, 6, 26),
  );
}

void main() {
  test('parses a batched passport probe', () async {
    final ssh = FakeSshService(scripted: {'@@OS@@': _fakeOutput});
    final passport = await ServerInspector(ssh).inspect(_server());

    expect(passport.osName, 'Ubuntu 22.04.3 LTS');
    expect(passport.kernel, '5.15.0-89-generic');
    expect(passport.uptime, 'up 3 days, 2 hours');
    expect(passport.cpuModel, contains('Intel'));
    expect(passport.cpuCores, 4);
    expect(passport.loadAverage, '0.15 0.10 0.05');
    expect(passport.memory, '512 / 1987 MB');
    expect(passport.disk, '8.1G / 25G (34%)');
    expect(passport.openPorts, [22, 80]);
    expect(passport.firewall, 'active');
    expect(passport.dockerContainers, ['3x-ui Up 2 hours']);
    expect(passport.nginxSites, ['landing']);
    // The "-- Logs begin --" header line is filtered out.
    expect(passport.recentErrors, ['nginx: connection reset']);
  });

  test('degrades gracefully when probes return nothing', () async {
    final ssh = FakeSshService(scripted: {'@@OS@@': ''});
    final passport = await ServerInspector(ssh).inspect(_server());

    expect(passport.osName, 'Unknown');
    expect(passport.cpuCores, 0);
    expect(passport.openPorts, isEmpty);
    expect(passport.firewall, 'unknown');
    expect(passport.dockerContainers, isEmpty);
  });
}
