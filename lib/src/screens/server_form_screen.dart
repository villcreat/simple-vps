import 'package:flutter/material.dart';

import '../app_controller.dart';
import '../app_strings.dart';
import '../models/models.dart';

enum _AuthType { password, key }

class ServerFormScreen extends StatefulWidget {
  const ServerFormScreen({
    required this.controller,
    this.existing,
    super.key,
  });

  final AppController controller;

  /// When set, the form edits this server instead of creating a new one.
  final Server? existing;

  @override
  State<ServerFormScreen> createState() => _ServerFormScreenState();
}

class _ServerFormScreenState extends State<ServerFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _host = TextEditingController();
  final _port = TextEditingController(text: '22');
  final _username = TextEditingController(text: 'root');
  final _note = TextEditingController();
  final _fingerprint = TextEditingController();
  final _password = TextEditingController();
  final _privateKey = TextEditingController();
  final _passphrase = TextEditingController();

  ServerOs _os = ServerOs.ubuntu;
  String _groupId = 'personal';
  _AuthType _authType = _AuthType.password;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    if (existing != null) {
      _name.text = existing.name;
      _host.text = existing.host;
      _port.text = '${existing.sshPort}';
      _username.text = existing.username;
      _note.text = existing.note;
      _fingerprint.text = existing.hostFingerprint;
      _os = existing.os;
      _groupId = widget.controller.groups.any((g) => g.id == existing.groupId)
          ? existing.groupId
          : 'personal';
      if (widget.controller.credentialFor(existing)?.isKey ?? false) {
        _authType = _AuthType.key;
      }
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _host.dispose();
    _port.dispose();
    _username.dispose();
    _note.dispose();
    _fingerprint.dispose();
    _password.dispose();
    _privateKey.dispose();
    _passphrase.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings(widget.controller.locale);
    final secretHelper =
        _isEdit ? strings.t('keepSecretHint') : strings.t('noSecretsStored');

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? strings.t('editServer') : strings.t('addServer')),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _name,
              decoration: InputDecoration(labelText: strings.t('name')),
              validator: _required(strings),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _host,
              decoration: InputDecoration(labelText: strings.t('host')),
              validator: _required(strings),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _port,
              decoration: InputDecoration(labelText: strings.t('port')),
              keyboardType: TextInputType.number,
              validator: (value) {
                final port = int.tryParse(value ?? '');
                if (port == null || port < 1 || port > 65535) {
                  return strings.t('required');
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _username,
              decoration: InputDecoration(labelText: strings.t('login')),
              validator: _required(strings),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<ServerOs>(
              initialValue: _os,
              decoration: InputDecoration(labelText: strings.t('os')),
              items: ServerOs.values
                  .map(
                    (os) => DropdownMenuItem(
                      value: os,
                      child: Text(os.label),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() => _os = value);
                }
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _groupId,
              decoration: InputDecoration(labelText: strings.t('group')),
              items: widget.controller.groups
                  .map(
                    (group) => DropdownMenuItem(
                      value: group.id,
                      child: Text(
                        widget.controller.locale.languageCode == 'ru'
                            ? group.nameRu
                            : group.nameEn,
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() => _groupId = value);
                }
              },
            ),
            const SizedBox(height: 20),
            Text(
              strings.t('authType'),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            SegmentedButton<_AuthType>(
              segments: [
                ButtonSegment(
                  value: _AuthType.password,
                  icon: const Icon(Icons.password),
                  label: Text(strings.t('password')),
                ),
                ButtonSegment(
                  value: _AuthType.key,
                  icon: const Icon(Icons.vpn_key),
                  label: Text(strings.t('privateKey')),
                ),
              ],
              selected: {_authType},
              onSelectionChanged: (value) {
                setState(() => _authType = value.first);
              },
            ),
            const SizedBox(height: 12),
            if (_authType == _AuthType.password)
              TextFormField(
                controller: _password,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: strings.t('password'),
                  helperText: secretHelper,
                ),
                validator: _isEdit ? null : _required(strings),
              )
            else ...[
              TextFormField(
                controller: _privateKey,
                maxLines: 5,
                decoration: InputDecoration(
                  labelText: strings.t('privateKey'),
                  helperText: secretHelper,
                  alignLabelWithHint: true,
                ),
                validator: _isEdit ? null : _required(strings),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _passphrase,
                obscureText: true,
                decoration: InputDecoration(labelText: strings.t('passphrase')),
              ),
            ],
            const SizedBox(height: 12),
            TextFormField(
              controller: _fingerprint,
              decoration: InputDecoration(labelText: strings.t('fingerprint')),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _note,
              maxLines: 3,
              decoration: InputDecoration(labelText: strings.t('note')),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.save),
              label: Text(strings.t('save')),
            ),
          ],
        ),
      ),
    );
  }

  String? Function(String?) _required(AppStrings strings) {
    return (value) {
      if (value == null || value.trim().isEmpty) {
        return strings.t('required');
      }
      return null;
    };
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final existing = widget.existing;
    final id = existing?.id ?? widget.controller.nextServerId();
    final reference = existing?.secretReference ?? id;

    final server = Server(
      id: id,
      name: _name.text.trim(),
      host: _host.text.trim(),
      sshPort: int.parse(_port.text.trim()),
      os: _os,
      username: _username.text.trim(),
      groupId: _groupId,
      note: _note.text.trim(),
      secretReference: reference,
      hostFingerprint: _fingerprint.text.trim(),
      createdAt: existing?.createdAt ?? DateTime.now(),
      lastConnectedAt: existing?.lastConnectedAt,
    );

    // Store the secret. When editing, an empty field keeps the current secret.
    if (_authType == _AuthType.password) {
      if (_password.text.isNotEmpty) {
        await widget.controller.setServerPassword(reference, _password.text);
      }
    } else {
      if (_privateKey.text.isNotEmpty) {
        await widget.controller.setServerKey(
          reference,
          _privateKey.text,
          passphrase:
              _passphrase.text.trim().isEmpty ? null : _passphrase.text.trim(),
        );
      }
    }

    if (existing != null) {
      await widget.controller.updateServer(server);
    } else {
      await widget.controller.addServer(server);
    }

    if (mounted) {
      Navigator.of(context).pop();
    }
  }
}
