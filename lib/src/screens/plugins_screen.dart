import 'package:flutter/material.dart';

import '../app_controller.dart';
import '../app_strings.dart';
import '../models/models.dart';
import 'dry_run_screen.dart';

class PluginsScreen extends StatefulWidget {
  const PluginsScreen({
    required this.controller,
    super.key,
  });

  final AppController controller;

  @override
  State<PluginsScreen> createState() => _PluginsScreenState();
}

class _PluginsScreenState extends State<PluginsScreen> {
  final _path = TextEditingController();
  ServerOs _os = ServerOs.ubuntu;
  bool _busy = false;

  @override
  void dispose() {
    _path.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings(widget.controller.locale);
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final plugins = widget.controller.plugins;
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              strings.t('plugins'),
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(strings.t('pluginsStub')),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: _path,
                      enabled: !_busy,
                      decoration: InputDecoration(
                        labelText: strings.t('pluginFolder'),
                        helperText: 'plugin.yaml',
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<ServerOs>(
                            initialValue: _os,
                            decoration:
                                InputDecoration(labelText: strings.t('os')),
                            items: ServerOs.values
                                .where((os) => os != ServerOs.unknown)
                                .map(
                                  (os) => DropdownMenuItem(
                                    value: os,
                                    child: Text(os.label),
                                  ),
                                )
                                .toList(),
                            onChanged: _busy
                                ? null
                                : (value) {
                                    if (value != null) {
                                      setState(() => _os = value);
                                    }
                                  },
                          ),
                        ),
                        const SizedBox(width: 12),
                        FilledButton.icon(
                          onPressed: _busy ? null : _load,
                          icon: const Icon(Icons.download),
                          label: Text(strings.t('loadPlugin')),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (plugins.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(strings.t('noPlugins')),
                ),
              )
            else
              ...plugins.map(
                (plugin) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  plugin.name,
                                  style:
                                      Theme.of(context).textTheme.titleLarge,
                                ),
                              ),
                              Chip(label: Text('v${plugin.version}')),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            plugin.scenario.supportedOs
                                .map((os) => os.label)
                                .join(', '),
                          ),
                          const SizedBox(height: 12),
                          FilledButton.icon(
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => DryRunScreen(
                                    controller: widget.controller,
                                    scenario: plugin.scenario,
                                  ),
                                ),
                              );
                            },
                            icon: const Icon(Icons.fact_check),
                            label: Text(strings.t('dryRun')),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Future<void> _load() async {
    final strings = AppStrings(widget.controller.locale);
    final messenger = ScaffoldMessenger.of(context);
    final path = _path.text.trim();
    if (path.isEmpty) {
      messenger.showSnackBar(SnackBar(content: Text(strings.t('required'))));
      return;
    }

    setState(() => _busy = true);
    try {
      final plugin = await widget.controller.loadPlugin(path, _os);
      messenger.showSnackBar(
        SnackBar(content: Text('${strings.t('pluginLoaded')}: ${plugin.name}')),
      );
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text('${strings.t('pluginLoadFailed')}: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }
}
