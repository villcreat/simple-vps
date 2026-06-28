# Server Inventory

Implemented in `lib/src/services/server_inspector.dart` (`ServerInspector` +
`ServerPassport`) and surfaced by `lib/src/screens/server_passport_screen.dart`.

It collects a passport over SSH with a single read-only command (probes bundled
behind `@@SECTION@@` markers): OS, kernel, uptime, CPU, cores, load, RAM, disk,
listening ports, firewall state, Docker containers, Nginx sites, and recent
journal errors. Installed services come from local state.

TODO: domains, per-provider snapshots, and persisting the last passport.
