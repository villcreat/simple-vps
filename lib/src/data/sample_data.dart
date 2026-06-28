import '../models/models.dart';
import 'install_scenarios.dart';

class SampleData {
  static const serverGroups = <ServerGroup>[
    ServerGroup(id: 'personal', nameRu: 'Личные', nameEn: 'Personal'),
    ServerGroup(id: 'vpn', nameRu: 'VPN', nameEn: 'VPN'),
    ServerGroup(id: 'games', nameRu: 'Игры', nameEn: 'Games'),
    ServerGroup(id: 'sites', nameRu: 'Сайты', nameEn: 'Websites'),
    ServerGroup(id: 'test', nameRu: 'Тестовые', nameEn: 'Test'),
    ServerGroup(id: 'work', nameRu: 'Рабочие', nameEn: 'Work'),
  ];

  /// Ids of the built-in groups — these cannot be renamed or deleted.
  static final Set<String> builtInGroupIds =
      serverGroups.map((group) => group.id).toSet();

  static bool isBuiltInGroup(String id) => builtInGroupIds.contains(id);

  static const catalog = <CatalogService>[
    CatalogService(
      id: '3x-ui',
      name: '3X-UI',
      category: 'VPN',
      descriptionRu: 'Панель управления VPN на Docker. Dry-run, бэкап и откат.',
      descriptionEn: 'Docker-based VPN panel. Dry-run, backup, and rollback.',
      scenarioId: '3x-ui',
      isAvailable: true,
    ),
    CatalogService(
      id: 'minecraft',
      name: 'Minecraft Server',
      category: 'Games',
      descriptionRu: 'Java-сервер Minecraft как systemd-сервис.',
      descriptionEn: 'Java Minecraft server as a systemd service.',
      scenarioId: 'minecraft',
      isAvailable: true,
    ),
    CatalogService(
      id: 'cs2',
      name: 'CS2 Server',
      category: 'Games',
      descriptionRu: 'Выделенный сервер CS2 через SteamCMD.',
      descriptionEn: 'CS2 dedicated server via SteamCMD.',
      scenarioId: 'cs2',
      isAvailable: true,
    ),
    CatalogService(
      id: 'gmod',
      name: "Garry's Mod Server",
      category: 'Games',
      descriptionRu: 'Сервер Garry\'s Mod через SteamCMD.',
      descriptionEn: "Garry's Mod server via SteamCMD.",
      scenarioId: 'gmod',
      isAvailable: true,
    ),
    CatalogService(
      id: 'landing',
      name: 'Landing page',
      category: 'Websites',
      descriptionRu: 'Статический лендинг на Nginx (порт 80).',
      descriptionEn: 'Static landing page served by Nginx (port 80).',
      scenarioId: 'landing',
      isAvailable: true,
    ),
    CatalogService(
      id: 'resume',
      name: 'Resume site',
      category: 'Websites',
      descriptionRu: 'Сайт-резюме на Nginx (порт 80).',
      descriptionEn: 'Resume site served by Nginx (port 80).',
      scenarioId: 'resume',
      isAvailable: true,
    ),
    CatalogService(
      id: 'bio',
      name: 'Bio site',
      category: 'Websites',
      descriptionRu: 'Сайт-биография на Nginx (порт 80).',
      descriptionEn: 'Bio site served by Nginx (port 80).',
      scenarioId: 'bio',
      isAvailable: true,
    ),
    CatalogService(
      id: 'portfolio',
      name: 'Portfolio site',
      category: 'Websites',
      descriptionRu: 'Сайт-портфолио на Nginx (порт 80).',
      descriptionEn: 'Portfolio site served by Nginx (port 80).',
      scenarioId: 'portfolio',
      isAvailable: true,
    ),
    CatalogService(
      id: 'weather',
      name: 'Weather site',
      category: 'Websites',
      descriptionRu: 'Погодный сайт на Nginx (порт 80).',
      descriptionEn: 'Weather site served by Nginx (port 80).',
      scenarioId: 'weather',
      isAvailable: true,
    ),
  ];

  static final threeXUiScenario = const Scenario(
    id: '3x-ui',
    name: '3X-UI',
    category: 'vpn',
    summary: 'Install 3X-UI with Docker, firewall preview, and rollback hints.',
    supportedOs: const [ServerOs.ubuntu, ServerOs.debian],
    steps: const [
      ScenarioStep(
        id: 'check_os',
        title: 'Check Linux distribution',
        command: 'cat /etc/os-release',
        safe: true,
        dangerous: false,
        reason: 'Reads OS metadata to choose the correct installer branch.',
      ),
      ScenarioStep(
        id: 'ensure_docker',
        title: 'Ensure Docker is installed',
        command:
            'docker --version || (sudo apt-get update && sudo apt-get install -y curl && curl -fsSL https://get.docker.com -o /tmp/get-docker.sh && sudo sh /tmp/get-docker.sh)',
        safe: false,
        dangerous: true,
        reason:
            'Installs Docker via the official get.docker.com script if it is '
            'not already present. Downloads and runs an external script.',
        rollbackHint:
            'Docker was installed by this step; remove it with apt if it is no '
            'longer needed.',
        rollbackCommand:
            'sudo apt-get remove -y docker-ce docker-ce-cli containerd.io docker-compose-plugin || true',
      ),
      ScenarioStep(
        id: 'backup_firewall',
        title: 'Plan firewall backup',
        command:
            'sudo apt-get install -y ufw && sudo mkdir -p /var/lib/vps-simple/backups/3x-ui && sudo ufw status verbose > /var/lib/vps-simple/backups/3x-ui/ufw.txt',
        safe: false,
        dangerous: false,
        filesChanged: ['/var/lib/vps-simple/backups/3x-ui/ufw.txt'],
        reason: 'Stores current firewall state before opening ports.',
        rollbackHint: 'Restore firewall policy from the saved backup file.',
      ),
      ScenarioStep(
        id: 'open_panel_port',
        title: 'Open 3X-UI panel port',
        command: 'sudo apt-get install -y ufw && sudo ufw allow 2053/tcp',
        safe: false,
        dangerous: true,
        reason: 'Opens a public TCP port for the panel. User confirmation is required.',
        portsOpened: [2053],
        rollbackHint: 'Close the public panel port again.',
        rollbackCommand: 'sudo ufw delete allow 2053/tcp',
      ),
      ScenarioStep(
        id: 'create_compose',
        title: 'Create Docker Compose file',
        command:
            'sudo mkdir -p /opt/3x-ui && sudo tee /opt/3x-ui/docker-compose.yml >/dev/null <<EOF\n'
            'services:\n'
            '  x-ui:\n'
            '    image: ghcr.io/mhsanaei/3x-ui:latest\n'
            '    container_name: 3x-ui\n'
            '    network_mode: host\n'
            '    volumes:\n'
            '      - /opt/3x-ui/db:/etc/x-ui\n'
            '    restart: unless-stopped\n'
            'EOF',
        safe: false,
        dangerous: true,
        reason: 'Writes a service definition under /opt/3x-ui.',
        filesChanged: ['/opt/3x-ui/docker-compose.yml'],
        rollbackHint: 'Remove /opt/3x-ui after confirming no user data is stored there.',
        rollbackCommand: 'sudo rm -rf /opt/3x-ui',
      ),
      ScenarioStep(
        id: 'start_service',
        title: 'Start 3X-UI container',
        command: 'cd /opt/3x-ui && sudo docker compose up -d',
        safe: false,
        dangerous: false,
        reason: 'Starts the container after explicit confirmation.',
        rollbackHint: 'Stop and remove the container.',
        rollbackCommand: 'cd /opt/3x-ui && sudo docker compose down',
      ),
    ],
  );

  /// Every built-in scenario, in catalog order.
  static final List<Scenario> scenarios = <Scenario>[
    threeXUiScenario,
    InstallScenarios.minecraft,
    InstallScenarios.cs2,
    InstallScenarios.gmod,
    InstallScenarios.landing,
    InstallScenarios.resume,
    InstallScenarios.bio,
    InstallScenarios.portfolio,
    InstallScenarios.weather,
  ];

  static Scenario? scenarioById(String id) {
    for (final scenario in scenarios) {
      if (scenario.id == id) {
        return scenario;
      }
    }
    return null;
  }
}
