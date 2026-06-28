import 'dart:async';

import 'package:flutter/material.dart';

import '../app_controller.dart';
import '../app_strings.dart';
import '../models/models.dart';
import '../services/execution/scenario_runner.dart';

/// Confirms, runs, and (if needed) rolls back a scenario over real SSH, showing
/// per-step status and a live log.
class ExecutionScreen extends StatefulWidget {
  const ExecutionScreen({
    required this.controller,
    required this.scenario,
    required this.server,
    super.key,
  });

  final AppController controller;
  final Scenario scenario;
  final Server server;

  @override
  State<ExecutionScreen> createState() => _ExecutionScreenState();
}

class _LogLine {
  const _LogLine(this.text, this.isError);

  final String text;
  final bool isError;
}

class _ExecutionScreenState extends State<ExecutionScreen> {
  static const _riskPhrases = {'я понимаю риск', 'i understand the risk'};

  final _phrase = TextEditingController();
  final _scroll = ScrollController();
  final Map<String, StepStatus> _stepStatus = {};
  final List<_LogLine> _log = [];

  StreamSubscription<ExecutionEvent>? _sub;
  bool _running = false;
  bool _finished = false;
  RunPhase? _finalPhase;

  bool get _hasDangerous =>
      widget.scenario.steps.any((step) => step.dangerous);

  bool get _phraseOk =>
      _riskPhrases.contains(_phrase.text.trim().toLowerCase());

  @override
  void initState() {
    super.initState();
    for (final step in widget.scenario.steps) {
      _stepStatus[step.id] = StepStatus.pending;
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    _phrase.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings(widget.controller.locale);
    final hasCredential = widget.controller.hasStoredSecret(widget.server);
    final canRun = !_running &&
        hasCredential &&
        (!_hasDangerous || _phraseOk) &&
        !_finished;

    return Scaffold(
      appBar: AppBar(title: Text(strings.t('execution'))),
      body: ListView(
        controller: _scroll,
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.scenario.name,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${widget.server.username}@${widget.server.host}:${widget.server.sshPort}'
                    ' · ${widget.server.os.label}',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (!hasCredential)
            _WarningCard(text: strings.t('noCredentialWarning')),
          if (!hasCredential) const SizedBox(height: 12),
          _SectionCard(
            title: strings.t('servicePlan'),
            child: Column(
              children: widget.scenario.steps
                  .map((step) => _StepTile(
                        step: step,
                        status: _stepStatus[step.id] ?? StepStatus.pending,
                      ))
                  .toList(),
            ),
          ),
          const SizedBox(height: 12),
          if (_hasDangerous && !_finished)
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
                        Expanded(child: Text(strings.t('riskPhrase'))),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _phrase,
                      enabled: !_running,
                      decoration: InputDecoration(
                        labelText: strings.t('riskPhraseInput'),
                        prefixIcon: const Icon(Icons.verified_user_outlined),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ],
                ),
              ),
            ),
          if (_hasDangerous && !_finished) const SizedBox(height: 12),
          if (!_finished)
            FilledButton.icon(
              onPressed: canRun ? _start : null,
              icon: _running
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.play_arrow),
              label: Text(strings.t('confirmAndRun')),
            ),
          if (_finished) ...[
            _ResultCard(phase: _finalPhase, strings: strings),
            const SizedBox(height: 12),
            if (widget.controller.canRollbackLastRun)
              OutlinedButton.icon(
                onPressed: _running ? null : _rollback,
                icon: const Icon(Icons.restore),
                label: Text(strings.t('rollback')),
              ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.of(context).maybePop(),
              child: Text(strings.t('close')),
            ),
          ],
          const SizedBox(height: 16),
          _SectionCard(
            title: strings.t('liveLog'),
            child: _LogView(lines: _log),
          ),
        ],
      ),
    );
  }

  void _start() {
    _runStream(widget.controller.runScenario(
      scenario: widget.scenario,
      server: widget.server,
      confirmedDangerous: !_hasDangerous || _phraseOk,
    ));
  }

  void _rollback() {
    for (final step in widget.scenario.steps) {
      _stepStatus[step.id] = StepStatus.pending;
    }
    _log.add(const _LogLine('--- rollback ---', false));
    _finished = false;
    _finalPhase = null;
    _runStream(widget.controller.rollbackLastRun());
  }

  void _runStream(Stream<ExecutionEvent> stream) {
    setState(() {
      _running = true;
      _finished = false;
    });

    _sub = stream.listen(
      _handleEvent,
      onError: (Object error) {
        setState(() {
          _log.add(_LogLine('Error: $error', true));
          _running = false;
          _finished = true;
          _finalPhase = RunPhase.failed;
        });
      },
      onDone: () {
        setState(() {
          _running = false;
          _finished = true;
        });
        _autoScroll();
      },
    );
  }

  void _handleEvent(ExecutionEvent event) {
    setState(() {
      switch (event.type) {
        case ExecutionEventType.log:
          if (event.message != null) {
            _log.add(_LogLine(event.message!, event.isError));
          }
        case ExecutionEventType.step:
          if (event.stepId != null && event.status != null) {
            _stepStatus[event.stepId!] = event.status!;
          }
        case ExecutionEventType.phase:
          if (event.phase != null) {
            _finalPhase = event.phase;
          }
      }
    });
    _autoScroll();
  }

  void _autoScroll() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.jumpTo(_scroll.position.maxScrollExtent);
      }
    });
  }
}

class _StepTile extends StatelessWidget {
  const _StepTile({required this.step, required this.status});

  final ScenarioStep step;
  final StepStatus status;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (icon, color) = switch (status) {
      StepStatus.pending => (Icons.radio_button_unchecked, scheme.outline),
      StepStatus.running => (Icons.sync, scheme.primary),
      StepStatus.success => (Icons.check_circle, Colors.green),
      StepStatus.failed => (Icons.error, scheme.error),
      StepStatus.skipped => (Icons.remove_circle_outline, scheme.outline),
    };

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: status == StepStatus.running
          ? const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(icon, color: color),
      title: Text(step.title),
      subtitle: Text(
        step.command,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: step.dangerous
          ? Icon(Icons.priority_high, color: scheme.error)
          : null,
    );
  }
}

class _LogView extends StatelessWidget {
  const _LogView({required this.lines});

  final List<_LogLine> lines;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (lines.isEmpty) {
      return const Text('—');
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: SelectableText.rich(
        TextSpan(
          children: [
            for (final line in lines)
              TextSpan(
                text: '${line.text}\n',
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12.5,
                  color: line.isError ? scheme.error : scheme.onSurface,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.phase, required this.strings});

  final RunPhase? phase;
  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final success = phase == RunPhase.success;
    return Card(
      color: success
          ? Colors.green.withValues(alpha: 0.12)
          : scheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(
              success ? Icons.check_circle : Icons.error,
              color: success ? Colors.green : scheme.error,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                success
                    ? '${strings.t('execution')}: OK'
                    : '${strings.t('execution')}: ${phase?.name ?? 'failed'}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WarningCard extends StatelessWidget {
  const _WarningCard({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      color: scheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.lock, color: scheme.onErrorContainer),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                text,
                style: TextStyle(color: scheme.onErrorContainer),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child});

  final String title;
  final Widget child;

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
            child,
          ],
        ),
      ),
    );
  }
}
