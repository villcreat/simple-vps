import 'package:flutter/material.dart';

import '../app_controller.dart';
import '../app_strings.dart';
import '../models/models.dart';
import '../services/server_inspector.dart';

/// Collects and shows a live "passport" of a server: OS, resources, open ports,
/// firewall, Docker, Nginx, installed services, and recent errors.
class ServerPassportScreen extends StatefulWidget {
  const ServerPassportScreen({
    required this.controller,
    required this.serverId,
    super.key,
  });

  final AppController controller;
  final String serverId;

  @override
  State<ServerPassportScreen> createState() => _ServerPassportScreenState();
}

class _ServerPassportScreenState extends State<ServerPassportScreen> {
  ServerPassport? _passport;
  String? _error;
  bool _noCredential = false;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _collect();
  }

  Future<void> _collect() async {
    final server = widget.controller.findServer(widget.serverId);
    if (server == null) {
      return;
    }
    if (!widget.controller.hasStoredSecret(server)) {
      setState(() {
        _noCredential = true;
        _loading = false;
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
      _noCredential = false;
    });
    try {
      final passport = await widget.controller.collectPassport(server);
      if (!mounted) return;
      setState(() {
        _passport = passport;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings(widget.controller.locale);
    final server = widget.controller.findServer(widget.serverId);

    return Scaffold(
      appBar: AppBar(
        title: Text(strings.t('passport')),
        actions: [
          IconButton(
            tooltip: strings.t('refresh'),
            onPressed: _loading ? null : _collect,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _body(context, strings, server),
    );
  }

  Widget _body(BuildContext context, AppStrings strings, Server? server) {
    if (server == null) {
      return Center(child: Text(strings.t('unknown')));
    }
    if (_noCredential) {
      return _Banner(text: strings.t('noCredentialWarning'));
    }
    if (_loading && _passport == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(strings.t('collecting')),
          ],
        ),
      );
    }
    if (_error != null && _passport == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline,
                  color: Theme.of(context).colorScheme.error, size: 40),
              const SizedBox(height: 12),
              Text('${strings.t('collectFailed')}: $_error',
                  textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _collect,
                icon: const Icon(Icons.refresh),
                label: Text(strings.t('refresh')),
              ),
            ],
          ),
        ),
      );
    }

    final passport = _passport;
    if (passport == null) {
      return const SizedBox.shrink();
    }
    return _report(context, strings, server, passport);
  }

  Widget _report(
    BuildContext context,
    AppStrings strings,
    Server server,
    ServerPassport p,
  ) {
    final services = widget.controller.servicesForServer(server.id);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _Section(
          title: strings.t('systemInfo'),
          children: [
            _Row(label: strings.t('os'), value: p.osName),
            _Row(label: strings.t('kernel'), value: p.kernel),
            _Row(label: 'Uptime', value: p.uptime),
            _Row(label: strings.t('cpu'), value: p.cpuModel),
            _Row(label: strings.t('cores'), value: '${p.cpuCores}'),
            _Row(label: strings.t('loadAverage'), value: p.loadAverage),
            _Row(label: strings.t('ram'), value: p.memory),
            _Row(label: strings.t('disk'), value: p.disk),
          ],
        ),
        const SizedBox(height: 12),
        _Section(
          title: strings.t('network'),
          children: [
            _Row(label: 'Firewall', value: p.firewall),
            const SizedBox(height: 8),
            Text(strings.t('ports'),
                style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 6),
            if (p.openPorts.isEmpty)
              Text(strings.t('none'))
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: p.openPorts
                    .map((port) => Chip(label: Text('$port')))
                    .toList(),
              ),
          ],
        ),
        const SizedBox(height: 12),
        _Section(
          title: 'Docker',
          children: _listOrNone(strings, p.dockerContainers),
        ),
        const SizedBox(height: 12),
        _Section(
          title: 'Nginx',
          children: _listOrNone(strings, p.nginxSites),
        ),
        const SizedBox(height: 12),
        _Section(
          title: strings.t('installedServices'),
          children: _listOrNone(
            strings,
            services.map((s) => '${s.name} (:${s.port})').toList(),
          ),
        ),
        const SizedBox(height: 12),
        _Section(
          title: strings.t('recentErrors'),
          children: _listOrNone(strings, p.recentErrors),
        ),
        const SizedBox(height: 16),
        Text(
          '${strings.t('collected')}: ${_formatTime(p.collectedAt)}',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }

  List<Widget> _listOrNone(AppStrings strings, List<String> items) {
    if (items.isEmpty) {
      return [Text(strings.t('none'))];
    }
    return items
        .map((item) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text('• $item'),
            ))
        .toList();
  }

  String _formatTime(DateTime date) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${date.year}-${two(date.month)}-${two(date.day)} '
        '${two(date.hour)}:${two(date.minute)}:${two(date.second)}';
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});

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
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(label, style: Theme.of(context).textTheme.labelLarge),
          ),
          Expanded(child: Text(value.isEmpty ? '—' : value)),
        ],
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Card(
        color: scheme.errorContainer,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(Icons.lock, color: scheme.onErrorContainer),
              const SizedBox(width: 12),
              Expanded(
                child: Text(text,
                    style: TextStyle(color: scheme.onErrorContainer)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
