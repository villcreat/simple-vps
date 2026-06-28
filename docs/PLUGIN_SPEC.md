# Plugin Specification

Plugins will add services, scenarios, command buttons, checks, and service-card
schemas. They must be reviewed before execution.

## Draft Structure

```text
plugin-example-service/
  plugin.yaml
  scripts/
    ubuntu_install.yaml
    debian_install.yaml
    windows_install.yaml
  ui/
    card_schema.json
  README.md
```

## Required Validation

Before a plugin scenario can run, VPS Simple must show:

- commands
- dangerous actions
- changed files
- opened ports
- required backups
- rollback hints

Execution requires user confirmation.

## Implemented Loader

`lib/src/services/plugin_loader.dart` (`PluginLoader`) loads a plugin folder:

1. Reads `plugin.yaml` (`id`, `name`, `version`, `entry`).
2. Resolves the installer for the target OS via `entry` (the key `windows` also
   matches `windows_server`).
3. Parses the referenced `scripts/<os>.yaml` (`os`, `steps` with
   `command`/`safe`/`dangerous`/`reason`/`files_changed`/`ports_opened`/
   `rollback`) into a normal `Scenario` (`category: plugin`).

The resulting scenario flows through the same dry-run preview, micro-backup,
risk-phrase confirmation, live log, and rollback as the built-in catalog — so the
required validation above is enforced by the existing flow. A command that looks
destructive is forced to `dangerous` even if the plugin did not declare it.
Loaded plugins are kept in memory for the session only.
