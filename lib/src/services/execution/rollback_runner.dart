import 'dart:convert';

import '../../models/models.dart';
import '../ssh_service.dart';
import 'scenario_runner.dart';

/// Reverts a scenario by running each executed step's explicit
/// [ScenarioStep.rollbackCommand] in reverse order.
///
/// Rollback is only ever triggered by an explicit user action. Steps without a
/// rollback command (for example read-only checks) are skipped. Prose
/// [ScenarioStep.rollbackHint]s are guidance for humans and are never executed.
class RollbackRunner {
  RollbackRunner(this.ssh);

  final SshService ssh;

  Stream<ExecutionEvent> run({
    required Scenario scenario,
    required Server server,
    required List<String> executedStepIds,
  }) async* {
    final stepsById = {for (final step in scenario.steps) step.id: step};
    final toRollback = executedStepIds
        .map((id) => stepsById[id])
        .whereType<ScenarioStep>()
        .where((step) => (step.rollbackCommand ?? '').isNotEmpty)
        .toList()
        .reversed
        .toList();

    if (toRollback.isEmpty) {
      yield ExecutionEvent.log(
        'No rollback commands are defined for the executed steps.',
      );
      yield ExecutionEvent.phase(RunPhase.success);
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
    yield ExecutionEvent.log('Connected. Rolling back ${toRollback.length} step(s).');

    var hadFailure = false;
    try {
      yield ExecutionEvent.phase(RunPhase.executing);
      for (final step in toRollback) {
        final command = step.rollbackCommand!;
        yield ExecutionEvent.step(step.id, StepStatus.running);
        yield ExecutionEvent.log('\$ $command', stepId: step.id);

        var exitCode = 0;
        await for (final chunk in session.exec(command)) {
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

        if (exitCode == 0) {
          yield ExecutionEvent.step(step.id, StepStatus.success);
        } else {
          hadFailure = true;
          yield ExecutionEvent.step(step.id, StepStatus.failed);
          yield ExecutionEvent.errorLine(
            'Rollback command exited with code $exitCode. Continuing with the rest.',
            stepId: step.id,
          );
        }
      }

      // Best-effort rollback keeps going even if one step fails, so the user
      // can finish reverting the remaining changes.
      yield ExecutionEvent.phase(hadFailure ? RunPhase.failed : RunPhase.success);
    } finally {
      await session.close();
    }
  }
}
