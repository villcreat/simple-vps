# Weather Website Scenario

Implemented in `lib/src/data/install_scenarios.dart` (`InstallScenarios.weather`),
built from the shared `_staticSite` recipe: Nginx + a static page under
`/var/www/weather` on port 80, with rollback for the dangerous steps. A live
weather data feed can be layered on later.
