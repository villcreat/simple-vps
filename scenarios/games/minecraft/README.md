# Minecraft Scenario

Implemented in `lib/src/data/install_scenarios.dart` (`InstallScenarios.minecraft`)
and surfaced in the catalog. Installs a Java Minecraft server as a systemd
service with a firewall rule on 25565 and rollback commands for the dangerous
steps.

Note: set the `server.jar` download URL for the version you want before running
(the recipe ships a placeholder URL on purpose).
