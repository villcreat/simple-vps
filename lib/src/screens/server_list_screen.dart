import 'package:flutter/material.dart';

import '../app_controller.dart';
import '../app_strings.dart';
import '../models/models.dart';
import 'server_detail_screen.dart';
import 'server_form_screen.dart';
import 'server_passport_screen.dart';
import 'ssh_terminal_screen.dart';

class ServerListScreen extends StatelessWidget {
  const ServerListScreen({
    required this.controller,
    super.key,
  });

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings(controller.locale);
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    strings.t('servers'),
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ),
                if (controller.servers.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: OutlinedButton.icon(
                      onPressed: controller.checkAllServers,
                      icon: const Icon(Icons.network_check),
                      label: Text(strings.t('checkAll')),
                    ),
                  ),
                FilledButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => ServerFormScreen(controller: controller),
                      ),
                    );
                  },
                  icon: const Icon(Icons.add),
                  label: Text(strings.t('addServer')),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (controller.servers.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      const Icon(Icons.dns_outlined, size: 40),
                      const SizedBox(height: 12),
                      Text(strings.t('emptyServers')),
                    ],
                  ),
                ),
              )
            else
              ...controller.servers.map(
                (server) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _ServerCard(
                    server: server,
                    controller: controller,
                    strings: strings,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _ServerCard extends StatelessWidget {
  const _ServerCard({
    required this.server,
    required this.controller,
    required this.strings,
  });

  final Server server;
  final AppController controller;
  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    final group = controller.groups.firstWhere(
      (item) => item.id == server.groupId,
      orElse: () => controller.groups.first,
    );
    final groupName =
        controller.locale.languageCode == 'ru' ? group.nameRu : group.nameEn;

    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        leading: CircleAvatar(
          child: Text(server.name.isEmpty ? '?' : server.name[0].toUpperCase()),
        ),
        title: Text(server.name),
        subtitle: Text('${server.username}@${server.host}:${server.sshPort}'),
        trailing: Wrap(
          spacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _StatusChip(
              status: controller.serverStatus(server.id),
              strings: strings,
            ),
            if (controller.serverStatus(server.id) == ServerStatus.checking)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 10),
                child: SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            else
              IconButton(
                tooltip: strings.t('checkConnection'),
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.network_check, size: 20),
                onPressed: () => controller.checkServer(server),
              ),
            Chip(label: Text(groupName)),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              onSelected: (value) => _menu(context, value),
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'passport',
                  child: Text(strings.t('passport')),
                ),
                PopupMenuItem(
                  value: 'terminal',
                  child: Text(strings.t('openTerminal')),
                ),
                PopupMenuItem(
                  value: 'delete',
                  child: Text(strings.t('delete')),
                ),
              ],
            ),
          ],
        ),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => ServerDetailScreen(
                controller: controller,
                serverId: server.id,
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _menu(BuildContext context, String action) async {
    switch (action) {
      case 'passport':
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => ServerPassportScreen(
              controller: controller,
              serverId: server.id,
            ),
          ),
        );
      case 'terminal':
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => SshTerminalScreen(
              controller: controller,
              serverId: server.id,
            ),
          ),
        );
      case 'delete':
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(strings.t('delete')),
            content: Text(strings.t('deleteServerConfirm')),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: Text(strings.t('cancel')),
              ),
              FilledButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: Text(strings.t('delete')),
              ),
            ],
          ),
        );
        if (confirmed == true) {
          await controller.deleteServer(server);
        }
    }
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status, required this.strings});

  final ServerStatus status;
  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (IconData icon, Color color, String key) = switch (status) {
      ServerStatus.online => (Icons.check_circle, Colors.green, 'online'),
      ServerStatus.offline => (Icons.error, scheme.error, 'offline'),
      ServerStatus.checking => (Icons.sync, scheme.primary, 'checking'),
      ServerStatus.unknown =>
        (Icons.circle_outlined, scheme.outline, 'statusOffline'),
    };
    return Chip(
      avatar: Icon(icon, size: 16, color: color),
      label: Text(strings.t(key)),
      visualDensity: VisualDensity.compact,
    );
  }
}
