import '../models/models.dart';

/// Built-in install recipes for the service catalog.
///
/// Each recipe is structured (not one giant bash blob) so the dry-run, preview,
/// micro-backup, and rollback flows can reason about it. Convention enforced by
/// tests: every step marked `dangerous` carries a `rollbackCommand`.
///
/// These are reviewable starting points — the user always sees the full plan in
/// the dry-run before anything runs. The 3X-UI recipe lives in `sample_data.dart`
/// and `scenarios/vpn/3x-ui/3x-ui.yaml` shows the documented file format.
class InstallScenarios {
  InstallScenarios._();

  static const List<ServerOs> _linux = [ServerOs.ubuntu, ServerOs.debian];

  static final Scenario minecraft = const Scenario(
    id: 'minecraft',
    name: 'Minecraft Server',
    category: 'games',
    summary:
        'Install a Java Minecraft server as a systemd service. Set the server '
        'jar URL for your version before running.',
    supportedOs: _linux,
    steps: const [
      ScenarioStep(
        id: 'check_java',
        title: 'Check Java',
        command: 'java -version',
        safe: true,
        dangerous: false,
        reason: 'Checks whether a Java runtime is already installed.',
      ),
      ScenarioStep(
        id: 'install_java',
        title: 'Install Java runtime',
        command:
            'sudo apt-get update && sudo apt-get install -y wget && '
            '(sudo apt-get install -y openjdk-21-jre-headless || '
            'sudo apt-get install -y openjdk-17-jre-headless || '
            'sudo apt-get install -y default-jre-headless)',
        safe: false,
        dangerous: false,
        reason: 'Installs a headless Java runtime (tries 21, then 17, then the '
            'distro default) plus wget.',
      ),
      ScenarioStep(
        id: 'create_dir',
        title: 'Create server directory',
        command: 'sudo mkdir -p /opt/minecraft',
        safe: false,
        dangerous: false,
        reason: 'Creates the install directory under /opt.',
      ),
      ScenarioStep(
        id: 'accept_eula',
        title: 'Accept the EULA',
        command: 'echo "eula=true" | sudo tee /opt/minecraft/eula.txt >/dev/null',
        safe: false,
        dangerous: false,
        reason: 'Writes the Mojang EULA acceptance file.',
        filesChanged: ['/opt/minecraft/eula.txt'],
        rollbackCommand: 'sudo rm -f /opt/minecraft/eula.txt',
      ),
      ScenarioStep(
        id: 'download_server',
        title: 'Download server jar (latest release)',
        command:
            "sudo apt-get install -y curl jq wget && "
            "V=\$(curl -s https://launchermeta.mojang.com/mc/game/version_manifest_v2.json | "
            "jq -r '.latest.release as \$r | .versions[] | select(.id==\$r) | .url') && "
            "S=\$(curl -s \"\$V\" | jq -r '.downloads.server.url') && "
            "sudo wget -O /opt/minecraft/server.jar \"\$S\"",
        safe: false,
        dangerous: true,
        reason:
            'Downloads the latest official Mojang server jar (resolved via the '
            'version manifest). Downloads an external binary.',
        filesChanged: ['/opt/minecraft/server.jar'],
        rollbackCommand: 'sudo rm -f /opt/minecraft/server.jar',
      ),
      ScenarioStep(
        id: 'create_service',
        title: 'Install systemd service',
        command: 'sudo tee /etc/systemd/system/minecraft.service >/dev/null <<EOF\n'
            '[Unit]\nDescription=Minecraft Server\nAfter=network.target\n'
            '[Service]\nWorkingDirectory=/opt/minecraft\n'
            'ExecStart=/usr/bin/java -Xmx2G -Xms1G -jar server.jar nogui\n'
            'Restart=on-failure\nUser=root\n'
            '[Install]\nWantedBy=multi-user.target\nEOF',
        safe: false,
        dangerous: true,
        reason: 'Writes a systemd unit under /etc.',
        filesChanged: ['/etc/systemd/system/minecraft.service'],
        rollbackCommand: 'sudo rm -f /etc/systemd/system/minecraft.service',
      ),
      ScenarioStep(
        id: 'open_port',
        title: 'Open Minecraft port',
        command: 'sudo ufw allow 25565/tcp',
        safe: false,
        dangerous: true,
        reason: 'Opens public TCP port 25565.',
        portsOpened: [25565],
        rollbackCommand: 'sudo ufw delete allow 25565/tcp',
      ),
      ScenarioStep(
        id: 'start_service',
        title: 'Enable and start',
        command: 'sudo systemctl daemon-reload && sudo systemctl enable --now minecraft',
        safe: false,
        dangerous: false,
        reason: 'Starts the server and enables it on boot.',
        rollbackCommand: 'sudo systemctl disable --now minecraft',
      ),
    ],
  );

  static final Scenario cs2 = _steamGame(
    id: 'cs2',
    name: 'CS2 Server',
    appId: 730,
    installDir: '/opt/cs2',
    serviceName: 'cs2',
    execStart: '/opt/cs2/game/bin/linuxsteamrt64/cs2 -dedicated +map de_dust2',
  );

  static final Scenario gmod = _steamGame(
    id: 'gmod',
    name: "Garry's Mod Server",
    appId: 4020,
    installDir: '/opt/gmod',
    serviceName: 'gmod',
    execStart: '/opt/gmod/srcds_run -game garrysmod +map gm_construct +maxplayers 16',
  );

  static final Scenario landing = const Scenario(
    id: 'landing',
    name: 'Landing page',
    category: 'websites',
    summary: 'Publish a static landing page served by Nginx on port 80.',
    supportedOs: _linux,
    steps: const [
      ScenarioStep(
        id: 'install_nginx',
        title: 'Install Nginx',
        command: 'sudo apt-get update && sudo apt-get install -y nginx',
        safe: false,
        dangerous: false,
        reason: 'Installs the Nginx web server via apt.',
      ),
      ScenarioStep(
        id: 'create_webroot',
        title: 'Create web root',
        command: 'sudo mkdir -p /var/www/landing',
        safe: false,
        dangerous: false,
        reason: 'Creates the static site directory.',
      ),
      ScenarioStep(
        id: 'write_index',
        title: 'Write index.html',
        command: 'sudo tee /var/www/landing/index.html >/dev/null <<EOF\n'
            '<!doctype html>\n<html lang="en">\n<head>\n'
            '<meta charset="utf-8">\n<title>VPS Simple Landing</title>\n'
            '</head>\n<body>\n<h1>It works.</h1>\n'
            '<p>Deployed with VPS Simple.</p>\n</body>\n</html>\nEOF',
        safe: false,
        dangerous: false,
        reason: 'Writes the landing page content.',
        filesChanged: ['/var/www/landing/index.html'],
        rollbackCommand: 'sudo rm -f /var/www/landing/index.html',
      ),
      ScenarioStep(
        id: 'write_vhost',
        title: 'Write Nginx site config',
        command: 'sudo tee /etc/nginx/sites-available/landing >/dev/null <<EOF\n'
            'server {\n  listen 80;\n  server_name _;\n'
            '  root /var/www/landing;\n  index index.html;\n}\nEOF',
        safe: false,
        dangerous: true,
        reason: 'Writes an Nginx site config under /etc.',
        filesChanged: ['/etc/nginx/sites-available/landing'],
        rollbackCommand:
            'sudo rm -f /etc/nginx/sites-available/landing /etc/nginx/sites-enabled/landing',
      ),
      ScenarioStep(
        id: 'enable_site',
        title: 'Enable the site',
        command:
            'sudo ln -sf /etc/nginx/sites-available/landing /etc/nginx/sites-enabled/landing',
        safe: false,
        dangerous: false,
        reason: 'Links the site into sites-enabled.',
        filesChanged: ['/etc/nginx/sites-enabled/landing'],
        rollbackCommand: 'sudo rm -f /etc/nginx/sites-enabled/landing',
      ),
      ScenarioStep(
        id: 'open_port',
        title: 'Open HTTP port',
        command: 'sudo ufw allow 80/tcp',
        safe: false,
        dangerous: true,
        reason: 'Opens public TCP port 80.',
        portsOpened: [80],
        rollbackCommand: 'sudo ufw delete allow 80/tcp',
      ),
      ScenarioStep(
        id: 'reload_nginx',
        title: 'Validate and reload Nginx',
        command: 'sudo nginx -t && sudo systemctl reload nginx',
        safe: false,
        dangerous: false,
        reason: 'Checks the config and reloads Nginx.',
      ),
    ],
  );

  /// Shared SteamCMD-based dedicated-server recipe (CS2, Garry's Mod, ...).
  static Scenario _steamGame({
    required String id,
    required String name,
    required int appId,
    required String installDir,
    required String serviceName,
    required String execStart,
    int port = 27015,
  }) {
    return Scenario(
      id: id,
      name: name,
      category: 'games',
      summary: 'Install $name via SteamCMD as a systemd service.',
      supportedOs: _linux,
      steps: [
        const ScenarioStep(
          id: 'enable_i386',
          title: 'Enable 32-bit packages',
          command: 'sudo dpkg --add-architecture i386 && sudo apt-get update',
          safe: false,
          dangerous: false,
          reason: 'SteamCMD requires 32-bit libraries.',
        ),
        const ScenarioStep(
          id: 'install_steamcmd',
          title: 'Install SteamCMD',
          command:
              'sudo apt-get install -y curl tar lib32gcc-s1 && '
              'sudo mkdir -p /opt/steamcmd && '
              'curl -sqL https://steamcdn-a.akamaihd.net/client/installer/steamcmd_linux.tar.gz '
              '| sudo tar zxf - -C /opt/steamcmd',
          safe: false,
          dangerous: false,
          reason:
              'Installs SteamCMD from the official Valve tarball '
              '(distro-independent) plus the 32-bit runtime libraries.',
        ),
        ScenarioStep(
          id: 'create_dir',
          title: 'Create install directory',
          command: 'sudo mkdir -p $installDir',
          safe: false,
          dangerous: false,
          reason: 'Creates the server install directory.',
        ),
        ScenarioStep(
          id: 'install_game',
          title: 'Download server files',
          command:
              '/opt/steamcmd/steamcmd.sh +force_install_dir $installDir +login anonymous +app_update $appId validate +quit',
          safe: false,
          dangerous: false,
          reason: 'Downloads the dedicated server via SteamCMD (large download).',
        ),
        ScenarioStep(
          id: 'create_service',
          title: 'Install systemd service',
          command: 'sudo tee /etc/systemd/system/$serviceName.service >/dev/null <<EOF\n'
              '[Unit]\nDescription=$name\nAfter=network.target\n'
              '[Service]\nWorkingDirectory=$installDir\n'
              'ExecStart=$execStart\nRestart=on-failure\nUser=root\n'
              '[Install]\nWantedBy=multi-user.target\nEOF',
          safe: false,
          dangerous: true,
          reason: 'Writes a systemd unit under /etc.',
          filesChanged: ['/etc/systemd/system/$serviceName.service'],
          rollbackCommand: 'sudo rm -f /etc/systemd/system/$serviceName.service',
        ),
        ScenarioStep(
          id: 'open_ports',
          title: 'Open game ports',
          command: 'sudo ufw allow $port/tcp && sudo ufw allow $port/udp',
          safe: false,
          dangerous: true,
          reason: 'Opens public ports $port (TCP/UDP).',
          portsOpened: [port],
          rollbackCommand:
              'sudo ufw delete allow $port/tcp && sudo ufw delete allow $port/udp',
        ),
        ScenarioStep(
          id: 'start_service',
          title: 'Enable and start',
          command:
              'sudo systemctl daemon-reload && sudo systemctl enable --now $serviceName',
          safe: false,
          dangerous: false,
          reason: 'Starts the server and enables it on boot.',
          rollbackCommand: 'sudo systemctl disable --now $serviceName',
        ),
      ],
    );
  }

  static final Scenario resume = _staticSite(
    id: 'resume',
    name: 'Resume site',
    slug: 'resume',
    heading: 'Your Name',
    body: 'Resume published with VPS Simple.',
  );

  static final Scenario bio = _staticSite(
    id: 'bio',
    name: 'Bio site',
    slug: 'bio',
    heading: 'About me',
    body: 'Biography published with VPS Simple.',
  );

  static final Scenario portfolio = _staticSite(
    id: 'portfolio',
    name: 'Portfolio site',
    slug: 'portfolio',
    heading: 'Portfolio',
    body: 'Portfolio published with VPS Simple.',
  );

  static final Scenario weather = _staticSite(
    id: 'weather',
    name: 'Weather site',
    slug: 'weather',
    heading: 'Weather',
    body: 'Weather page published with VPS Simple.',
  );

  /// Shared static-website recipe: Nginx + a single page on port 80. Mirrors the
  /// `landing` scenario; the Nginx config write and the port open are dangerous
  /// and carry rollback commands.
  static Scenario _staticSite({
    required String id,
    required String name,
    required String slug,
    required String heading,
    required String body,
  }) {
    final root = '/var/www/$slug';
    final site = '/etc/nginx/sites-available/$slug';
    final enabled = '/etc/nginx/sites-enabled/$slug';
    return Scenario(
      id: id,
      name: name,
      category: 'websites',
      summary: 'Publish a static $name served by Nginx on port 80.',
      supportedOs: _linux,
      steps: [
        const ScenarioStep(
          id: 'install_nginx',
          title: 'Install Nginx',
          command: 'sudo apt-get update && sudo apt-get install -y nginx',
          safe: false,
          dangerous: false,
          reason: 'Installs the Nginx web server via apt.',
        ),
        ScenarioStep(
          id: 'create_webroot',
          title: 'Create web root',
          command: 'sudo mkdir -p $root',
          safe: false,
          dangerous: false,
          reason: 'Creates the static site directory.',
        ),
        ScenarioStep(
          id: 'write_index',
          title: 'Write index.html',
          command: 'sudo tee $root/index.html >/dev/null <<EOF\n'
              '<!doctype html>\n<html lang="en">\n<head>\n'
              '<meta charset="utf-8">\n<title>$name</title>\n</head>\n'
              '<body>\n<h1>$heading</h1>\n<p>$body</p>\n</body>\n</html>\nEOF',
          safe: false,
          dangerous: false,
          reason: 'Writes the page content.',
          filesChanged: ['$root/index.html'],
          rollbackCommand: 'sudo rm -f $root/index.html',
        ),
        ScenarioStep(
          id: 'write_vhost',
          title: 'Write Nginx site config',
          command: 'sudo tee $site >/dev/null <<EOF\n'
              'server {\n  listen 80;\n  server_name _;\n'
              '  root $root;\n  index index.html;\n}\nEOF',
          safe: false,
          dangerous: true,
          reason: 'Writes an Nginx site config under /etc.',
          filesChanged: [site],
          rollbackCommand: 'sudo rm -f $site $enabled',
        ),
        ScenarioStep(
          id: 'enable_site',
          title: 'Enable the site',
          command: 'sudo ln -sf $site $enabled',
          safe: false,
          dangerous: false,
          reason: 'Links the site into sites-enabled.',
          filesChanged: [enabled],
          rollbackCommand: 'sudo rm -f $enabled',
        ),
        const ScenarioStep(
          id: 'open_port',
          title: 'Open HTTP port',
          command: 'sudo apt-get install -y ufw && sudo ufw allow 80/tcp',
          safe: false,
          dangerous: true,
          reason: 'Opens public TCP port 80.',
          portsOpened: [80],
          rollbackCommand: 'sudo ufw delete allow 80/tcp',
        ),
        const ScenarioStep(
          id: 'reload_nginx',
          title: 'Validate and reload Nginx',
          command: 'sudo nginx -t && sudo systemctl reload nginx',
          safe: false,
          dangerous: false,
          reason: 'Checks the config and reloads Nginx.',
        ),
      ],
    );
  }
}
