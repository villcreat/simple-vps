import 'package:flutter/material.dart';

import '../app_controller.dart';
import '../app_strings.dart';
import 'backups_screen.dart';
import 'installed_services_screen.dart';
import 'logs_screen.dart';
import 'plugins_screen.dart';
import 'security_log_screen.dart';
import 'server_list_screen.dart';
import 'service_catalog_screen.dart';
import 'settings_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({
    required this.controller,
    super.key,
  });

  final AppController controller;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings(widget.controller.locale);
    final destinations = _destinations(strings);
    final pages = [
      ServerListScreen(controller: widget.controller),
      ServiceCatalogScreen(controller: widget.controller),
      InstalledServicesScreen(controller: widget.controller),
      LogsScreen(controller: widget.controller),
      BackupsScreen(controller: widget.controller),
      SettingsScreen(controller: widget.controller),
      PluginsScreen(controller: widget.controller),
      SecurityLogScreen(controller: widget.controller),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(destinations[_index].label),
        actions: [
          IconButton(
            tooltip: strings.t('lock'),
            onPressed: widget.controller.lock,
            icon: const Icon(Icons.lock),
          ),
          const SizedBox(width: 8),
        ],
      ),
      drawer: NavigationDrawer(
        selectedIndex: _index,
        onDestinationSelected: (value) {
          setState(() => _index = value);
          Navigator.of(context).pop();
        },
        children: destinations
            .map(
              (item) => NavigationDrawerDestination(
                icon: Icon(item.icon),
                selectedIcon: Icon(item.selectedIcon),
                label: Text(item.label),
              ),
            )
            .toList(),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth >= 900) {
            return Row(
              children: [
                NavigationRail(
                  selectedIndex: _index,
                  onDestinationSelected: (value) {
                    setState(() => _index = value);
                  },
                  labelType: NavigationRailLabelType.all,
                  destinations: destinations
                      .map(
                        (item) => NavigationRailDestination(
                          icon: Icon(item.icon),
                          selectedIcon: Icon(item.selectedIcon),
                          label: Text(item.label),
                        ),
                      )
                      .toList(),
                ),
                const VerticalDivider(width: 1),
                Expanded(child: pages[_index]),
              ],
            );
          }

          return Column(
            children: [
              Expanded(child: pages[_index]),
              NavigationBar(
                selectedIndex: _index < 5 ? _index : 0,
                onDestinationSelected: (value) {
                  setState(() => _index = value);
                },
                destinations: destinations
                    .take(5)
                    .map(
                      (item) => NavigationDestination(
                        icon: Icon(item.icon),
                        selectedIcon: Icon(item.selectedIcon),
                        label: item.label,
                      ),
                    )
                    .toList(),
              ),
            ],
          );
        },
      ),
    );
  }

  List<_Destination> _destinations(AppStrings strings) {
    return [
      _Destination(
        label: strings.t('servers'),
        icon: Icons.dns_outlined,
        selectedIcon: Icons.dns,
      ),
      _Destination(
        label: strings.t('catalog'),
        icon: Icons.widgets_outlined,
        selectedIcon: Icons.widgets,
      ),
      _Destination(
        label: strings.t('installedServices'),
        icon: Icons.inventory_2_outlined,
        selectedIcon: Icons.inventory_2,
      ),
      _Destination(
        label: strings.t('logs'),
        icon: Icons.subject_outlined,
        selectedIcon: Icons.subject,
      ),
      _Destination(
        label: strings.t('backups'),
        icon: Icons.restore_outlined,
        selectedIcon: Icons.restore,
      ),
      _Destination(
        label: strings.t('settings'),
        icon: Icons.settings_outlined,
        selectedIcon: Icons.settings,
      ),
      _Destination(
        label: strings.t('plugins'),
        icon: Icons.extension_outlined,
        selectedIcon: Icons.extension,
      ),
      _Destination(
        label: strings.t('securityLog'),
        icon: Icons.admin_panel_settings_outlined,
        selectedIcon: Icons.admin_panel_settings,
      ),
    ];
  }
}

class _Destination {
  const _Destination({
    required this.label,
    required this.icon,
    required this.selectedIcon,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;
}
