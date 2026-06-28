import 'dart:convert';

import '../../models/models.dart';
import '../ssh_service.dart';

enum StepStatus { pending, running, success, failed, skipped }

enum RunPhase { connecting, backup, executing, success, failed, aborted }

enum ExecutionEventType { log, step, phase }

/// A single event emitted while a scenario (or rollback) runs. Screens render
/// these as live log lines and per-step status updates.
class ExecutionEvent {
  ExecutionEvent.log(this.message, {this.stepId})
      : type = ExecutionEventType.log,
        status = null,
        phase = null,
        isError = false;

  ExecutionEvent.errorLine(this.message, {this.stepId})
      : type = ExecutionEventType.log,
        status = null,
        phase = null,
        isError = true;

  ExecutionEvent.step(this.stepId, this.status)
      : type = ExecutionEventType.step,
        message = null,
        phase = null,
        isError = false;

  ExecutionEvent.phase(this.phase)
      : type = ExecutionEventType.phase,
        message = null,
        stepId = null,
        status = null,
        isError = false;

  final ExecutionEventType type;
  final String? message;
  final String? stepId;
  final StepStatus? status;
  final RunPhase? phase;
  final bool isError;
}

/// Executes a confirmed scenario over a single SSH session.
///
/// Safety contract:
/// - dangerous scenarios refuse to run unless [confirmedDangerous] is true;
/// - a micro-backup of every file the scenario touches is taken first;
/// - execution stops on the first non-zero exit code so partial failures do not
///   cascade. The caller can then offer rollback.
class ScenarioRunner {
  ScenarioRunner(this.ssh);

  final SshService ssh;

  Stream<ExecutionEvent> run({
    required Scenario scenario,
    required Server server,
    required bool confirmedDangerous,
    required String backupPath,
  }) async* {
    if (!scenario.supportedOs.contains(server.os)) {
      yield ExecutionEvent.errorLine(
        'Scenario "${scenario.name}" does not support ${server.os.label}.',
      );
      yield ExecutionEvent.phase(RunPhase.aborted);
      return;
    }

    final hasDangerous = scenario.steps.any((step) => step.dangerous);
    if (hasDangerous && !confirmedDangerous) {
      yield ExecutionEvent.errorLine(
        'Dangerous steps require explicit confirmation. Execution aborted.',
      );
      yield ExecutionEvent.phase(RunPhase.aborted);
      return;
    }

    yield ExecutionEvent.phase(RunPhase.connecting);
    yield ExecutionEvent.log(
      'Connecting to ${server.username}@${server.host}:${server.sshPort} ...',
    );

    final SshSession session;
    try {
      session = await ssh.open(server);
    } catch (error) {
      yield ExecutionEvent.errorLine('Connection failed: $error');
      yield ExecutionEvent.phase(RunPhase.failed);
      return;
    }
    yield ExecutionEvent.log('Connected.');

    try {
      final files = <String>{
        for (final step in scenario.steps) ...step.filesChanged,
      };
      if (files.isNotEmpty) {
        yield ExecutionEvent.phase(RunPhase.backup);
        yield ExecutionEvent.log('Creating micro-backup under $backupPath ...');
        await _drain(session.exec('sudo mkdir -p "$backupPath"'));
        for (final file in files) {
          yield ExecutionEvent.log('Backing up $file');
          await _drain(
            session.exec(
              'if [ -e "$file" ]; then sudo cp -a "$file" "$backupPath"/ ; fi',
            ),
          );
        }
      }

      yield ExecutionEvent.phase(RunPhase.executing);
      for (final step in scenario.steps) {
        yield ExecutionEvent.step(step.id, StepStatus.running);
        yield ExecutionEvent.log('\$ ${step.command}', stepId: step.id);

        var exitCode = 0;
        await for (final chunk in session.exec(step.command)) {
          if (chunk.isDone) {
            exitCode = chunk.exitCode ?? 0;
            continue;
          }
          final text = chunk.text;
          if (text == null || text.isEmpty) {
            continue;
          }
          for (final line in const LineSplitter().convert(text)) {
            yield chunk.isError
                ? ExecutionEvent.errorLine(line, stepId: step.id)
                : ExecutionEvent.log(line, stepId: step.id);
          }
        }

        if (exitCode != 0) {
          yield ExecutionEvent.step(step.id, StepStatus.failed);
          yield ExecutionEvent.errorLine(
            'Step "${step.title}" failed with exit code $exitCode.',
            stepId: step.id,
          );
          yield ExecutionEvent.phase(RunPhase.failed);
          return;
        }
        yield ExecutionEvent.step(step.id, StepStatus.success);
      }

      yield ExecutionEvent.phase(RunPhase.success);
    } finally {
      await session.close();
    }
  }

  Future<void> _drain(Stream<SshChunk> stream) async {
    await for (final _ in stream) {
      // Best-effort: backup command output is intentionally ignored.
    }
  }
}
