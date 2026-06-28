import 'package:flutter/material.dart';

import '../app_controller.dart';
import '../app_strings.dart';

class LogsScreen extends StatelessWidget {
  const LogsScreen({
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
        final history = controller.installHistory;
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              strings.t('logs'),
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),
            if (history.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(strings.t('logsEmpty')),
                ),
              )
            else
              ...history.map((entry) {
                final server = controller.findServer(entry.serverId);
                final icon = switch (entry.status) {
                  'success' => Icons.check_circle,
                  'rolled_back' => Icons.restore,
                  _ => Icons.error,
                };
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Card(
                    child: ListTile(
                      leading: Icon(icon),
                      title: Text('${entry.scenarioId} · ${entry.status}'),
                      subtitle: Text(
                        '${server?.name ?? entry.serverId}\n'
                        '${entry.commands.length} ${strings.t('logs').toLowerCase()} · '
                        '${_formatDate(entry.startedAt)}',
                      ),
                      isThreeLine: true,
                      trailing: entry.rollbackUsed
                          ? const Icon(Icons.undo)
                          : null,
                    ),
                  ),
                );
              }),
          ],
        );
      },
    );
  }

  String _formatDate(DateTime date) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${date.year}-${two(date.month)}-${two(date.day)} '
        '${two(date.hour)}:${two(date.minute)}';
  }
}
