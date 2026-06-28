import 'package:flutter/material.dart';

import '../app_controller.dart';
import '../app_strings.dart';
import '../models/models.dart';
import '../services/command_safety.dart';
import '../services/ssh_service.dart';

/// Built-in SSH terminal: runs commands over one connection, streams output,
/// keeps a per-session history, and requires the risk phrase before running a
/// command flagged as dangerous.
///
/// Each command runs in a fresh shell (no persistent cwd); `cd` does not carry
/// over between commands.
class SshTerminalScreen extends StatefulWidget {
  const SshTerminalScreen({
    required this.controller,
    required this.serverId,
    this.initialCommand,
    super.key,
  });

  final AppController controller;
  final String serverId;

  /// Pre-fills the command input (used by service management buttons).
  final String? initialCommand;

  @override
  State<SshTerminalScreen> createState() => _SshTerminalScreenState();
}

enum _LineKind { command, output, error, system }

class _TermLine {
  const _TermLine(this.text, this.kind);

  final String text;
  final _LineKind kind;
}

class _SshTerminalScreenState extends State<SshTerminalScreen> {
  static const _riskPhrases = {'я понимаю риск', 'i understand the risk'};

  final _input = TextEditingController();
  final _scroll = ScrollController();
  final _focus = FocusNode();
  final List<_TermLine> _output = [];
  final List<String> _history = [];

  SshSession? _session;
  bool _connecting = false;
  bool _noCredential = false;
  String? _connError;
  bool _running = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialCommand != null) {
      _input.text = widget.initialCommand!;
    }
    _connect();
  }

  @override
  void dispose() {
    _session?.close();
    _input.dispose();
    _scroll.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _connect() async {
    final server = widget.controller.findServer(widget.serverId);
    if (server == null) {
      return;
    }
    if (!widget.controller.hasStoredSecret(server)) {
      setState(() => _noCredential = true);
      return;
    }

    setState(() {
      _connecting = true;
      _connError = null;
    });
    try {
      final session = await widget.controller.sshService.open(server);
      if (!mounted) {
        await session.close();
        return;
      }
      setState(() {
        _session = session;
        _connecting = false;
        _output.add(_TermLine(
          'Connected to ${server.username}@${server.host}:${server.sshPort}',
          _LineKind.system,
        ));
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _connecting = false;
        _connError = error.toString();
      });
    }
  }

  Future<void> _run() async {
    final command = _input.text.trim();
    final server = widget.controller.findServer(widget.serverId);
    final session = _session;
    if (command.isEmpty || _running || session == null || server == null) {
      return;
    }

    final reasons = CommandSafety.reasons(command);
    if (reasons.isNotEmpty) {
      final confirmed = await _confirmDangerous(command, reasons);
      if (!confirmed) {
        return;
      }
      await widget.controller.logDangerousCommand(server, command);
    }

    _history.remove(command);
    _history.insert(0, command);
    _input.clear();
    setState(() {
      _running = true;
      _output.add(_TermLine('\$ $command', _LineKind.command));
    });
    _autoScroll();

    try {
      await for (final chunk in session.exec(command)) {
        if (!mounted) return;
        if (chunk.isDone || chunk.text == null || chunk.text!.isEmpty) {
          continue;
        }
        setState(() {
          for (final line in chunk.text!.split('\n')) {
            if (line.isEmpty) continue;
            _output.add(_TermLine(
              line,
              chunk.isError ? _LineKind.error : _LineKind.output,
            ));
          }
          _trim();
        });
        _autoScroll();
      }
    } catch (error) {
      if (mounted) {
        setState(() => _output.add(_TermLine('Error: $error', _LineKind.error)));
      }
    } finally {
      if (mounted) {
        setState(() => _running = false);
        _focus.requestFocus();
        _autoScroll();
      }
    }
  }

  Future<bool> _confirmDangerous(String command, List<String> reasons) async {
    final strings = AppStrings(widget.controller.locale);
    final phrase = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setLocal) {
            final ok = _riskPhrases.contains(phrase.text.trim().toLowerCase());
            return AlertDialog(
              title: Text(strings.t('dangerousCommandTitle')),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(command,
                      style: const TextStyle(fontFamily: 'monospace')),
                  const SizedBox(height: 8),
                  Text('${strings.t('dangerousActions')}: ${reasons.join(', ')}'),
                  const SizedBox(height: 12),
                  Text(strings.t('riskPhrase')),
                  const SizedBox(height: 8),
                  TextField(
                    controller: phrase,
                    autofocus: true,
                    decoration: InputDecoration(
                      labelText: strings.t('riskPhraseInput'),
                    ),
                    onChanged: (_) => setLocal(() {}),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: Text(strings.t('cancel')),
                ),
                FilledButton(
                  onPressed: ok ? () => Navigator.of(context).pop(true) : null,
                  child: Text(strings.t('run')),
                ),
              ],
            );
          },
        );
      },
    );
    phrase.dispose();
    return result ?? false;
  }

  void _trim() {
    if (_output.length > 2000) {
      _output.removeRange(0, _output.length - 2000);
    }
  }

  void _autoScroll() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.jumpTo(_scroll.position.maxScrollExtent);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings(widget.controller.locale);
    final server = widget.controller.findServer(widget.serverId);

    return Scaffold(
      appBar: AppBar(
        title: Text('${strings.t('openTerminal')} · ${server?.name ?? ''}'),
        actions: [
          if (_history.isNotEmpty)
            PopupMenuButton<String>(
              tooltip: strings.t('history'),
              icon: const Icon(Icons.history),
              onSelected: (value) {
                _input.text = value;
                _focus.requestFocus();
              },
              itemBuilder: (context) => _history
                  .take(20)
                  .map((c) => PopupMenuItem(value: c, child: Text(c)))
                  .toList(),
            ),
          IconButton(
            tooltip: strings.t('clearLog'),
            onPressed: () => setState(_output.clear),
            icon: const Icon(Icons.clear_all),
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
    if (_connecting) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(strings.t('connecting')),
          ],
        ),
      );
    }
    if (_connError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline,
                  color: Theme.of(context).colorScheme.error, size: 40),
              const SizedBox(height: 12),
              Text('${strings.t('connectFailed')}: $_connError',
                  textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _connect,
                icon: const Icon(Icons.refresh),
                label: Text(strings.t('reconnect')),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        Expanded(child: _TerminalLog(lines: _output, scroll: _scroll)),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _input,
                  focusNode: _focus,
                  autofocus: true,
                  enabled: !_running,
                  style: const TextStyle(fontFamily: 'monospace'),
                  decoration: InputDecoration(
                    prefixText: '\$ ',
                    hintText: strings.t('commandHint'),
                    border: const OutlineInputBorder(),
                  ),
                  onSubmitted: (_) => _run(),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: _running ? null : _run,
                child: _running
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(strings.t('run')),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TerminalLog extends StatelessWidget {
  const _TerminalLog({required this.lines, required this.scroll});

  final List<_TermLine> lines;
  final ScrollController scroll;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Color colorFor(_LineKind kind) => switch (kind) {
          _LineKind.command => scheme.primary,
          _LineKind.error => scheme.error,
          _LineKind.system => scheme.outline,
          _LineKind.output => scheme.onSurface,
        };

    return Container(
      width: double.infinity,
      color: scheme.surfaceContainerHighest,
      child: SingleChildScrollView(
        controller: scroll,
        padding: const EdgeInsets.all(12),
        child: SelectableText.rich(
          TextSpan(
            children: [
              for (final line in lines)
                TextSpan(
                  text: '${line.text}\n',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12.5,
                    color: colorFor(line.kind),
                  ),
                ),
            ],
          ),
        ),
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
