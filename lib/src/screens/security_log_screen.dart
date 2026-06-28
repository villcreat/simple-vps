import 'package:flutter/material.dart';

import '../app_controller.dart';
import '../app_strings.dart';

class SecurityLogScreen extends StatelessWidget {
  const SecurityLogScreen({
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
            Text(
              strings.t('securityLog'),
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),
            if (controller.securityEvents.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(strings.t('noEventsYet')),
                ),
              )
            else
              ...controller.securityEvents.map(
                (event) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Card(
                    child: ListTile(
                      leading: const Icon(Icons.admin_panel_settings),
                      title: Text(event.title),
                      subtitle: Text(event.description),
                      trailing: Text(event.severity.id),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
