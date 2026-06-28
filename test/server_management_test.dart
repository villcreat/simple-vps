import 'package:flutter_test/flutter_test.dart';
import 'package:vps_simple/src/app_controller.dart';
import 'package:vps_simple/src/data/sample_data.dart';
import 'package:vps_simple/src/models/models.dart';
import 'package:vps_simple/src/services/local_json_store.dart';

import 'fake_ssh_service.dart';

/// In-memory metadata store so the controller never touches disk.
class _MemStore extends LocalJsonStore {
  Map<String, dynamic> data = {};

  @override
  Future<Map<String, dynamic>> read() async => data;

  @override
  Future<void> write(Map<String, dynamic> value) async => data = value;
}

Server _server(String id, String name) => Server(
      id: id,
      name: name,
      host: '10.0.0.1',
      sshPort: 22,
      os: ServerOs.ubuntu,
      username: 'root',
      groupId: 'personal',
      note: '',
      secretReference: id,
      hostFingerprint: '',
      createdAt: DateTime(2026, 6, 26),
    );

AppController _controller() =>
    AppController(store: _MemStore(), sshService: FakeSshService());

void main() {
  test('add, update, and delete a server', () async {
    final controller = _controller();

    await controller.addServer(_server('s1', 'Old name'));
    expect(controller.servers.single.name, 'Old name');

    await controller.updateServer(_server('s1', 'New name'));
    expect(controller.servers.single.name, 'New name');

    await controller.deleteServer(controller.servers.single);
    expect(controller.servers, isEmpty);
  });

  test('deleting a server cascades to its services and backups', () async {
    final controller = _controller();
    await controller.addServer(_server('s1', 'Srv'));

    controller.installedServices.add(
      InstalledService(
        id: 'svc',
        serverId: 's1',
        name: 'X',
        version: '1',
        port: 80,
        status: 'running',
        installPath: '/opt/x',
        installedAt: DateTime(2026, 1, 1),
        category: 'vpn',
        autoUpdateEnabled: false,
      ),
    );
    controller.backups.add(
      Backup(
        id: 'b1',
        serverId: 's1',
        path: '/var/x',
        type: 'pre-install',
        createdAt: DateTime(2026, 1, 1),
        sizeBytes: 0,
        status: 'available',
        canRollback: true,
      ),
    );

    await controller.deleteServer(controller.servers.single);
    expect(controller.installedServices, isEmpty);
    expect(controller.backups, isEmpty);
  });

  test('checkServer reports online then offline', () async {
    final ssh = FakeSshService();
    final controller = AppController(store: _MemStore(), sshService: ssh);
    await controller.addServer(_server('s1', 'Srv'));

    await controller.checkServer(controller.servers.single);
    expect(controller.serverStatus('s1'), ServerStatus.online);

    ssh.connectionOk = false;
    await controller.checkServer(controller.servers.single);
    expect(controller.serverStatus('s1'), ServerStatus.offline);
  });

  test('add and rename custom groups; built-ins are protected', () async {
    final controller = _controller();

    await controller.addGroup('My Group');
    final group = controller.groups.firstWhere((g) => g.nameRu == 'My Group');
    expect(SampleData.isBuiltInGroup(group.id), isFalse);

    await controller.renameGroup(group.id, 'Renamed');
    expect(
      controller.groups.firstWhere((g) => g.id == group.id).nameRu,
      'Renamed',
    );

    await controller.renameGroup('personal', 'Hacked');
    expect(
      controller.groups.firstWhere((g) => g.id == 'personal').nameRu,
      isNot('Hacked'),
    );
    await controller.deleteGroup('personal');
    expect(controller.groups.any((g) => g.id == 'personal'), isTrue);
  });

  test('deleting a group moves its servers to personal', () async {
    final controller = _controller();
    await controller.addGroup('Temp');
    final group = controller.groups.firstWhere((g) => g.nameRu == 'Temp');

    await controller.addServer(
      Server(
        id: 'srv',
        name: 'S',
        host: '10.0.0.1',
        sshPort: 22,
        os: ServerOs.ubuntu,
        username: 'root',
        groupId: group.id,
        note: '',
        secretReference: 'srv',
        hostFingerprint: '',
        createdAt: DateTime(2026, 6, 27),
      ),
    );
    expect(controller.servers.single.groupId, group.id);

    await controller.deleteGroup(group.id);
    expect(controller.servers.single.groupId, 'personal');
    expect(controller.groups.any((g) => g.id == group.id), isFalse);
  });

  test('uploadFile and downloadFile delegate to the ssh service', () async {
    final ssh = FakeSshService();
    final controller = AppController(store: _MemStore(), sshService: ssh);
    await controller.uploadFile(
      _server('s1', 'S'),
      localPath: '/local/a',
      remotePath: '/remote/b',
    );
    await controller.downloadFile(
      _server('s1', 'S'),
      remotePath: '/remote/c',
      localPath: '/local/d',
    );
    expect(ssh.transfers, ['up:/local/a->/remote/b', 'down:/remote/c->/local/d']);
  });
}
