# Garry's Mod Scenario

Implemented in `lib/src/data/install_scenarios.dart` (`InstallScenarios.gmod`).
SteamCMD-based dedicated server (app id 4020) installed as a systemd service,
with firewall rules on 27015 (TCP/UDP) and rollback commands for the dangerous
steps. Shares the `_steamGame` recipe with CS2.
