import 'package:flutter/material.dart';

import '../app_controller.dart';
import '../app_strings.dart';
import '../models/models.dart';
import 'dry_run_screen.dart';

class ServiceCatalogScreen extends StatelessWidget {
  const ServiceCatalogScreen({
    required this.controller,
    this.selectedServerId,
    super.key,
  });

  final AppController controller;
  final String? selectedServerId;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings(controller.locale);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          strings.t('catalog'),
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 16),
        ...controller.catalog.map(
          (service) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _CatalogCard(
              controller: controller,
              service: service,
              selectedServerId: selectedServerId,
            ),
          ),
        ),
      ],
    );
  }
}

class _CatalogCard extends StatelessWidget {
  const _CatalogCard({
    required this.controller,
    required this.service,
    required this.selectedServerId,
  });

  final AppController controller;
  final CatalogService service;
  final String? selectedServerId;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings(controller.locale);
    final description = controller.locale.languageCode == 'ru'
        ? service.descriptionRu
        : service.descriptionEn;
    final scenario = controller.scenarioById(service.scenarioId);
    final enabled = service.isAvailable && scenario != null;

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
                Chip(label: Text(service.category)),
              ],
            ),
            const SizedBox(height: 8),
            Text(description),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: enabled
                  ? () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => DryRunScreen(
                            controller: controller,
                            scenario: scenario,
                            serverId: selectedServerId,
                          ),
                        ),
                      );
                    }
                  : null,
              icon: const Icon(Icons.fact_check),
              label: Text(strings.t('dryRun')),
            ),
          ],
        ),
      ),
    );
  }
}
