import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_controller.dart';
import '../app_strings.dart';
import '../models/models.dart';
import 'server_form_screen.dart';
import 'server_passport_screen.dart';
import 'service_catalog_screen.dart';
import 'sftp_screen.dart';
import 'ssh_terminal_screen.dart';

class ServerDetailScreen extends StatelessWidget {
  const ServerDetailScreen({
    required this.controller,
    required this.serverId,
    super.key,
  });

  final AppController controller;
  final String serverId;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings(controller.locale);
    final server = controller.findServer(serverId);
    if (server == null) {
      return Scaffold(
        appBar: AppBar(title: Text(strings.t('serverCard'))),
        body: Center(child: Text(strings.t('unknown'))),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(server.name),
        actions: [
          IconButton(
            tooltip: strings.t('edit'),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => ServerFormScreen(
                    controller: controller,
                    existing: server,
                  ),
                ),
              );
            },
            icon: const Icon(Icons.edit_outlined),
          ),
          IconButton(
            tooltip: strings.t('delete'),
            onPressed: () => _delete(context, strings, server),
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    strings.t('serverCard'),
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  _InfoRow(label: strings.t('host'), value: server.host),
                  _InfoRow(label: strings.t('port'), value: '${server.sshPort}'),
                  _InfoRow(label: strings.t('login'), value: server.username),
                  _InfoRow(label: strings.t('os'), value: server.os.label),
                  _InfoRow(
                    label: strings.t('fingerprint'),
                    value: server.hostFingerprint.isEmpty
                        ? strings.t('unknown')
                        : server.hostFingerprint,
                  ),
                  if (controller.hasStoredSecret(server)) ...[
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: OutlinedButton.icon(
                        onPressed: () =>
                            _showCredential(context, strings, server),
                        icon: const Icon(Icons.visibility_outlined),
                        label: Text(strings.t('showCredential')),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    strings.t('passport'),
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _MetricChip(label: strings.t('cpu'), value: '--'),
                      _MetricChip(label: strings.t('ram'), value: '--'),
                      _MetricChip(label: strings.t('disk'), value: '--'),
                      _MetricChip(
                        label: strings.t('statusOffline'),
                        value: server.os.label,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    strings.t('sshMetricsStub'),
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Builder(
            builder: (context) {
              final services = controller.servicesForServer(server.id);
              if (services.isEmpty) {
                return const SizedBox.shrink();
              }
              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          strings.t('installedServices'),
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        ...services.map(
                          (service) => ListTile(
                            contentPadding: EdgeInsets.zero,
                            dense: true,
                            title: Text(service.name),
                            subtitle: Text(
                              '${service.status}'
                              '${service.port == 0 ? '' : ' · :${service.port}'}',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              FilledButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => Scaffold(
                        appBar: AppBar(title: Text(strings.t('catalog'))),
                        body: ServiceCatalogScreen(
                          controller: controller,
                          selectedServerId: server.id,
                        ),
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.add_task),
                label: Text(strings.t('openCatalog')),
              ),
              FilledButton.tonalIcon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => ServerPassportScreen(
                        controller: controller,
                        serverId: server.id,
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.fact_check_outlined),
                label: Text(strings.t('passport')),
              ),
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => SshTerminalScreen(
                        controller: controller,
                        serverId: server.id,
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.terminal),
                label: Text(strings.t('openTerminal')),
              ),
              OutlinedButton.icon(
                onPressed: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  await controller.checkServer(server);
                  final online =
                      controller.serverStatus(server.id) == ServerStatus.online;
                  final message =
                      controller.serverStatusMessage(server.id) ?? '';
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text(
                        '${strings.t(online ? 'online' : 'offline')} · '
                        '${message.split('\n').first}',
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.network_check),
                label: Text(strings.t('checkConnection')),
              ),
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => SftpScreen(
                        controller: controller,
                        serverId: server.id,
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.folder_outlined),
                label: Text(strings.t('sftp')),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _delete(
    BuildContext context,
    AppStrings strings,
    Server server,
  ) async {
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
    if (confirmed != true || !context.mounted) {
      return;
    }
    final navigator = Navigator.of(context);
    await controller.deleteServer(server);
    navigator.pop();
  }

  Future<void> _showCredential(
    BuildContext context,
    AppStrings strings,
    Server server,
  ) async {
    final credential = controller.credentialFor(server);
    if (credential == null) {
      return;
    }
    await controller.logSecretViewed(server);
    final secret = credential.isKey
        ? (credential.privateKeyPem ?? '')
        : (credential.password ?? '');
    if (!context.mounted) {
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(strings.t('credential')),
        content: SingleChildScrollView(
          child: SelectableText(
            secret,
            style: const TextStyle(fontFamily: 'monospace'),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: secret));
              messenger.showSnackBar(
                SnackBar(content: Text(strings.t('copied'))),
              );
              Navigator.of(ctx).pop();
            },
            child: Text(strings.t('copy')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(strings.t('close')),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: Theme.of(context).textTheme.labelLarge,
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}

class _MetricChip extends StatelessWidget {
  const _MetricChip({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Chip(label: Text('$label: $value'));
  }
}
