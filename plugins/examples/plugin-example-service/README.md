# Example Service Plugin

A minimal plugin that demonstrates the loadable structure: `plugin.yaml`
(metadata + per-OS `entry`) and `scripts/<os>.yaml` installers. Its single step
is a harmless `echo`/`Write-Output` preview.

Load it from the Plugins screen by pointing at this folder and picking an OS, or
in code via `PluginLoader.loadFromDirectory(...)`. The loaded scenario runs
through the normal dry-run, confirmation, and rollback flow — replace the step
with real commands to make it do something.
