import 'dart:io';

import 'package:flutter/material.dart';

import '../app_controller.dart';
import '../app_strings.dart';
import '../data/sample_data.dart';
import '../models/models.dart';
import '../services/crypto/export_service.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({
    required this.controller,
    super.key,
  });

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings(controller.locale);
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              strings.t('settings'),
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),
            _Card(
              title: strings.t('theme'),
              child: SegmentedButton<ThemeMode>(
                segments: [
                  ButtonSegment(
                    value: ThemeMode.system,
                    icon: const Icon(Icons.brightness_auto),
                    label: Text(strings.t('system')),
                  ),
                  ButtonSegment(
                    value: ThemeMode.light,
                    icon: const Icon(Icons.light_mode),
                    label: Text(strings.t('light')),
                  ),
                  ButtonSegment(
                    value: ThemeMode.dark,
                    icon: const Icon(Icons.dark_mode),
                    label: Text(strings.t('dark')),
                  ),
                ],
                selected: {controller.themeMode},
                onSelectionChanged: (value) =>
                    controller.setThemeMode(value.first),
              ),
            ),
            const SizedBox(height: 12),
            _Card(
              title: strings.t('language'),
              child: SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'ru', label: Text('RU')),
                  ButtonSegment(value: 'en', label: Text('EN')),
                ],
                selected: {controller.locale.languageCode},
                onSelectionChanged: (value) =>
                    controller.setLocale(Locale(value.first)),
              ),
            ),
            const SizedBox(height: 12),
            _Card(
              title: strings.t('autoLock'),
              child: Align(
                alignment: Alignment.centerLeft,
                child: DropdownButton<int>(
                  value: controller.autoLockMinutes,
                  items: [
                    for (final minutes in (<int>{
                      0,
                      5,
                      10,
                      15,
                      30,
                      controller.autoLockMinutes,
                    }.toList()
                      ..sort()))
                      DropdownMenuItem(
                        value: minutes,
                        child: Text(
                          minutes == 0
                              ? strings.t('autoLockOff')
                              : '$minutes ${strings.t('minutesUnit')}',
                        ),
                      ),
                    DropdownMenuItem(
                      value: -1,
                      child: Text(strings.t('customMinutes')),
                    ),
                  ],
                  onChanged: (value) {
                    if (value == null) {
                      return;
                    }
                    if (value == -1) {
                      _promptCustomLock(context, strings);
                    } else {
                      controller.setAutoLockMinutes(value);
                    }
                  },
                ),
              ),
            ),
            const SizedBox(height: 12),
            _GroupsCard(controller: controller),
            const SizedBox(height: 12),
            _ExportImportCard(controller: controller),
          ],
        );
      },
    );
  }

  Future<void> _promptCustomLock(BuildContext context, AppStrings strings) async {
    final input = TextEditingController(text: '${controller.autoLockMinutes}');
    final result = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(strings.t('autoLock')),
        content: TextField(
          controller: input,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(labelText: strings.t('minutesUnit')),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(strings.t('cancel')),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(ctx).pop(int.tryParse(input.text.trim())),
            child: Text(strings.t('save')),
          ),
        ],
      ),
    );
    input.dispose();
    if (result != null && result >= 0) {
      await controller.setAutoLockMinutes(result);
    }
  }
}

class _ExportImportCard extends StatefulWidget {
  const _ExportImportCard({required this.controller});

  final AppController controller;

  @override
  State<_ExportImportCard> createState() => _ExportImportCardState();
}

class _ExportImportCardState extends State<_ExportImportCard> {
  late final TextEditingController _path =
      TextEditingController(text: _defaultPath());
  final _exportPassword = TextEditingController();
  final _importPassword = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _path.dispose();
    _exportPassword.dispose();
    _importPassword.dispose();
    super.dispose();
  }

  String _defaultPath() {
    final home = Platform.environment['USERPROFILE'] ??
        Platform.environment['HOME'] ??
        '.';
    return '$home${Platform.pathSeparator}vps-simple-export.json';
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings(widget.controller.locale);
    return _Card(
      title: strings.t('exportImport'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(strings.t('exportImportHint')),
          const SizedBox(height: 12),
          TextField(
            controller: _path,
            enabled: !_busy,
            decoration: InputDecoration(labelText: strings.t('filePath')),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _exportPassword,
            obscureText: true,
            enabled: !_busy,
            decoration:
                InputDecoration(labelText: strings.t('exportPassword')),
          ),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: _busy ? null : _export,
            icon: const Icon(Icons.upload_file),
            label: Text(strings.t('exportBtn')),
          ),
          const Divider(height: 32),
          TextField(
            controller: _importPassword,
            obscureText: true,
            enabled: !_busy,
            decoration:
                InputDecoration(labelText: strings.t('importPassword')),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _busy ? null : _import,
            icon: const Icon(Icons.download),
            label: Text(strings.t('importBtn')),
          ),
        ],
      ),
    );
  }

  Future<void> _export() async {
    final strings = AppStrings(widget.controller.locale);
    final messenger = ScaffoldMessenger.of(context);
    if (_exportPassword.text.isEmpty || _path.text.trim().isEmpty) {
      messenger.showSnackBar(SnackBar(content: Text(strings.t('required'))));
      return;
    }

    setState(() => _busy = true);
    try {
      await widget.controller.exportToFile(
        password: _exportPassword.text,
        path: _path.text.trim(),
      );
      messenger.showSnackBar(SnackBar(content: Text(strings.t('exportDone'))));
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text('${strings.t('importFailed')}: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _import() async {
    final strings = AppStrings(widget.controller.locale);
    final messenger = ScaffoldMessenger.of(context);
    if (_importPassword.text.isEmpty || _path.text.trim().isEmpty) {
      messenger.showSnackBar(SnackBar(content: Text(strings.t('required'))));
      return;
    }

    setState(() => _busy = true);
    try {
      final added = await widget.controller.importFromFile(
        password: _importPassword.text,
        path: _path.text.trim(),
      );
      messenger.showSnackBar(
        SnackBar(content: Text('${strings.t('importDone')}: $added')),
      );
    } on ExportPasswordException {
      messenger.showSnackBar(
        SnackBar(content: Text(strings.t('wrongFilePassword'))),
      );
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text('${strings.t('importFailed')}: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

class _GroupsCard extends StatefulWidget {
  const _GroupsCard({required this.controller});

  final AppController controller;

  @override
  State<_GroupsCard> createState() => _GroupsCardState();
}

class _GroupsCardState extends State<_GroupsCard> {
  final _name = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  String _label(ServerGroup group) =>
      widget.controller.locale.languageCode == 'ru'
          ? group.nameRu
          : group.nameEn;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings(widget.controller.locale);
    return _Card(
      title: strings.t('serverGroups'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ...widget.controller.groups.map((group) {
            final builtIn = SampleData.isBuiltInGroup(group.id);
            return ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text(_label(group)),
              subtitle: builtIn ? Text(strings.t('builtIn')) : null,
              trailing: builtIn
                  ? null
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: strings.t('rename'),
                          icon: const Icon(Icons.edit_outlined),
                          onPressed: () => _rename(group),
                        ),
                        IconButton(
                          tooltip: strings.t('delete'),
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () => _delete(group),
                        ),
                      ],
                    ),
            );
          }),
          const Divider(),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _name,
                  decoration:
                      InputDecoration(labelText: strings.t('groupName')),
                  onSubmitted: (_) => _add(),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: _add,
                icon: const Icon(Icons.add),
                label: Text(strings.t('addGroup')),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _add() async {
    if (_name.text.trim().isEmpty) {
      return;
    }
    await widget.controller.addGroup(_name.text);
    _name.clear();
  }

  Future<void> _rename(ServerGroup group) async {
    final strings = AppStrings(widget.controller.locale);
    final controller = TextEditingController(text: _label(group));
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(strings.t('rename')),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(labelText: strings.t('groupName')),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(strings.t('cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text),
            child: Text(strings.t('save')),
          ),
        ],
      ),
    );
    controller.dispose();
    if (result != null && result.trim().isNotEmpty) {
      await widget.controller.renameGroup(group.id, result);
    }
  }

  Future<void> _delete(ServerGroup group) async {
    final strings = AppStrings(widget.controller.locale);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(strings.t('delete')),
        content: Text(strings.t('deleteGroupConfirm')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(strings.t('cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(strings.t('delete')),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await widget.controller.deleteGroup(group.id);
    }
  }
}
