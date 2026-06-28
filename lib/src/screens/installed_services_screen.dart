import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_controller.dart';
import '../app_strings.dart';
import '../models/models.dart';
import 'ssh_terminal_screen.dart';

class InstalledServicesScreen extends StatelessWidget {
  const InstalledServicesScreen({
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
        final services = controller.installedServices;
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              strings.t('installedServices'),
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),
            if (services.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(strings.t('installedEmpty')),
                ),
              )
            else
              ...services.map(
                (service) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _ServiceCard(
                    controller: controller,
                    service: service,
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

class _ServiceCard extends StatelessWidget {
  const _ServiceCard({
    required this.controller,
    required this.service,
    required this.strings,
  });

  final AppController controller;
  final InstalledService service;
  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    final server = controller.findServer(service.serverId);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    service.name,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                Chip(label: Text(service.status)),
              ],
            ),
            const SizedBox(height: 8),
            if (server != null) Text('${server.name} · ${server.host}'),
            Text(
              '${strings.t('servicePort')}: '
              '${service.port == 0 ? '—' : service.port}',
            ),
            Text('${strings.t('installPath')}: ${service.installPath}'),
            if (service.login != null)
              Text('${strings.t('login')}: ${service.login}'),
            if (service.url != null)
              Row(
                children: [
                  Expanded(child: Text(service.url!)),
                  IconButton(
                    tooltip: strings.t('copy'),
                    icon: const Icon(Icons.copy, size: 18),
                    onPressed: () => _copy(context, service.url!),
                  ),
                ],
              ),
            if (server != null && service.controlCommands.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: service.controlCommands.entries
                    .map(
                      (entry) => OutlinedButton(
                        onPressed: () =>
                            _runControl(context, server, entry.value),
                        child: Text(entry.key),
                      ),
                    )
                    .toList(),
              ),
            ],
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => _delete(context),
                icon: const Icon(Icons.delete_outline),
                label: Text(strings.t('delete')),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _runControl(BuildContext context, Server server, String command) {
    // Opens the terminal with the command prefilled: editable, and dangerous
    // commands still require the risk phrase before running (spec §20).
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SshTerminalScreen(
          controller: controller,
          serverId: server.id,
          initialCommand: command,
        ),
      ),
    );
  }

  void _copy(BuildContext context, String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(strings.t('copied'))),
    );
  }

  Future<void> _delete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(strings.t('delete')),
        content: Text(strings.t('deleteServiceConfirm')),
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
      await controller.removeInstalledService(service.id);
    }
  }
}
