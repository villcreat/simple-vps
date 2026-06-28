# Landing Website Scenario

Implemented in `lib/src/data/install_scenarios.dart` (`InstallScenarios.landing`).
Installs Nginx, writes a static page under `/var/www/landing`, adds an Nginx site
config, opens port 80, and reloads Nginx. The Nginx config write and the port
open are marked dangerous and carry rollback commands.
