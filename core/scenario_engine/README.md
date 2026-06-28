# Scenario Engine

Dry-run report building lives in `lib/src/services/scenario_engine.dart`. Real
execution lives in `lib/src/services/execution/`:

- `scenario_runner.dart` — `ScenarioRunner` runs a confirmed scenario over one
  SSH session, takes a micro-backup first, streams `ExecutionEvent`s, and stops
  on the first failing step.
- `rollback_runner.dart` — `RollbackRunner` reverts a completed run using each
  step's `rollbackCommand`, in reverse, on explicit user request.

Execution stays behind preview, the risk phrase, backup, confirmation, and
logging.
