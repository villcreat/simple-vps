# CS2 Scenario

Implemented in `lib/src/data/install_scenarios.dart` (`InstallScenarios.cs2`).
SteamCMD-based dedicated server (app id 730) installed as a systemd service,
with firewall rules on 27015 (TCP/UDP) and rollback commands for the dangerous
steps.
