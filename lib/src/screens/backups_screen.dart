import 'package:flutter/material.dart';

import '../app_controller.dart';
import '../app_strings.dart';

class BackupsScreen extends StatelessWidget {
  const BackupsScreen({
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
        final backups = controller.backups;
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              strings.t('backups'),
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),
            if (backups.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(strings.t('backupsEmpty')),
                ),
              )
            else
              ...backups.map((backup) {
                final server = controller.findServer(backup.serverId);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Card(
                    child: ListTile(
                      leading: const Icon(Icons.restore_page),
                      title: Text(backup.path),
                      subtitle: Text(
                        '${server?.name ?? backup.serverId} · ${backup.type} · '
                        '${backup.status}',
                      ),
                      trailing: backup.canRollback
                          ? const Icon(Icons.history)
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
}
