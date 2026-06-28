import 'package:flutter/material.dart';

import '../app_controller.dart';
import '../app_strings.dart';
import '../models/models.dart';
import 'execution_screen.dart';

class DryRunScreen extends StatelessWidget {
  const DryRunScreen({
    required this.controller,
    required this.scenario,
    this.serverId,
    super.key,
  });

  final AppController controller;
  final Scenario scenario;
  final String? serverId;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings(controller.locale);
    final server = serverId == null
        ? _firstServerOrDemo()
        : controller.findServer(serverId!) ?? _demoServer();
    final report = controller.scenarioEngine.dryRun(
      scenario: scenario,
      server: server,
    );

    return Scaffold(
      appBar: AppBar(title: Text(strings.t('dryRun'))),
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
                    report.scenario.name,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(report.scenario.summary),
                  const SizedBox(height: 12),
                  Chip(
                    avatar: const Icon(Icons.visibility_outlined),
                    label: Text(strings.t('dryRunHint')),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (report.warnings.isNotEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.warning_amber,
                          color: Theme.of(context).colorScheme.error,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          strings.t('dangerousActions'),
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ...report.warnings.map(
                      (warning) => Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Text('- $warning'),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(strings.t('riskPhrase')),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 12),
          _SectionCard(
            title: strings.t('servicePlan'),
            children: [
              ...report.steps.map(
                (step) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    step.dangerous ? Icons.priority_high : Icons.check_circle,
                  ),
                  title: Text(step.title),
                  subtitle: Text(step.command),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _SectionCard(
            title: strings.t('files'),
            children: _textLines(report.filesChanged),
          ),
          const SizedBox(height: 12),
          _SectionCard(
            title: strings.t('ports'),
            children:
                _textLines(report.portsOpened.map((port) => '$port/tcp')),
          ),
          const SizedBox(height: 12),
          _SectionCard(
            title: strings.t('backups'),
            children: _textLines(report.backupsPlanned),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => ExecutionScreen(
                    controller: controller,
                    scenario: scenario,
                    server: server,
                  ),
                ),
              );
            },
            icon: const Icon(Icons.play_arrow),
            label: Text(strings.t('confirmInstall')),
          ),
        ],
      ),
    );
  }

  List<Widget> _textLines(Iterable<String> values) {
    final list = values.toList();
    if (list.isEmpty) {
      return const [Text('-')];
    }

    return list
        .map(
          (value) => Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text('- $value'),
          ),
        )
        .toList();
  }

  Server _firstServerOrDemo() {
    if (controller.servers.isEmpty) {
      return _demoServer();
    }
    return controller.servers.first;
  }

  Server _demoServer() {
    return Server(
      id: 'demo',
      name: 'Demo VPS',
      host: '203.0.113.10',
      sshPort: 22,
      os: ServerOs.ubuntu,
      username: 'root',
      groupId: 'test',
      note: 'Dry-run demo server',
      secretReference: '',
      hostFingerprint: '',
      createdAt: DateTime.now(),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.children,
  });

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            ...children,
          ],
        ),
      ),
    );
  }
}
