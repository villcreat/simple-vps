# Backup Engine

First version implemented inside `lib/src/services/execution/scenario_runner.dart`:
before executing a scenario, the runner copies every file the scenario will touch
into `/var/lib/vps-simple/backups/<timestamp>_<scenario>/` and records a `Backup`
entry. `RollbackRunner` then reverts changes via per-step rollback commands.

TODO:

- restore-from-backup picker (currently rollback uses commands, not file restore)
- backup size accounting and retention
- provider snapshots where available
