import 'package:flutter/material.dart';

import '../app_controller.dart';
import '../app_strings.dart';
import '../models/models.dart';

/// Simple path-based SFTP transfer: upload a local file to the server or
/// download a remote file. No file-picker dependency — paths are typed.
class SftpScreen extends StatefulWidget {
  const SftpScreen({
    required this.controller,
    required this.serverId,
    super.key,
  });

  final AppController controller;
  final String serverId;

  @override
  State<SftpScreen> createState() => _SftpScreenState();
}

class _SftpScreenState extends State<SftpScreen> {
  final _uploadLocal = TextEditingController();
  final _uploadRemote = TextEditingController();
  final _downloadRemote = TextEditingController();
  final _downloadLocal = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _uploadLocal.dispose();
    _uploadRemote.dispose();
    _downloadRemote.dispose();
    _downloadLocal.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings(widget.controller.locale);
    final server = widget.controller.findServer(widget.serverId);

    return Scaffold(
      appBar: AppBar(title: Text(strings.t('sftp'))),
      body: _body(context, strings, server),
    );
  }

  Widget _body(BuildContext context, AppStrings strings, Server? server) {
    if (server == null) {
      return Center(child: Text(strings.t('unknown')));
    }
    if (!widget.controller.hasStoredSecret(server)) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Card(
          color: Theme.of(context).colorScheme.errorContainer,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text(strings.t('noCredentialWarning')),
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _Card(
          title: strings.t('upload'),
          children: [
            TextField(
              controller: _uploadLocal,
              enabled: !_busy,
              decoration: InputDecoration(labelText: strings.t('localPath')),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _uploadRemote,
              enabled: !_busy,
              decoration: InputDecoration(labelText: strings.t('remotePath')),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _busy ? null : () => _upload(server),
              icon: const Icon(Icons.upload_file),
              label: Text(strings.t('upload')),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _Card(
          title: strings.t('download'),
          children: [
            TextField(
              controller: _downloadRemote,
              enabled: !_busy,
              decoration: InputDecoration(labelText: strings.t('remotePath')),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _downloadLocal,
              enabled: !_busy,
              decoration: InputDecoration(labelText: strings.t('localPath')),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _busy ? null : () => _download(server),
              icon: const Icon(Icons.download),
              label: Text(strings.t('download')),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _upload(Server server) async {
    final strings = AppStrings(widget.controller.locale);
    final messenger = ScaffoldMessenger.of(context);
    if (_uploadLocal.text.trim().isEmpty || _uploadRemote.text.trim().isEmpty) {
      messenger.showSnackBar(SnackBar(content: Text(strings.t('required'))));
      return;
    }
    setState(() => _busy = true);
    try {
      await widget.controller.uploadFile(
        server,
        localPath: _uploadLocal.text.trim(),
        remotePath: _uploadRemote.text.trim(),
      );
      messenger.showSnackBar(SnackBar(content: Text(strings.t('uploaded'))));
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

  Future<void> _download(Server server) async {
    final strings = AppStrings(widget.controller.locale);
    final messenger = ScaffoldMessenger.of(context);
    if (_downloadRemote.text.trim().isEmpty ||
        _downloadLocal.text.trim().isEmpty) {
      messenger.showSnackBar(SnackBar(content: Text(strings.t('required'))));
      return;
    }
    setState(() => _busy = true);
    try {
      await widget.controller.downloadFile(
        server,
        remotePath: _downloadRemote.text.trim(),
        localPath: _downloadLocal.text.trim(),
      );
      messenger.showSnackBar(SnackBar(content: Text(strings.t('downloaded'))));
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
  const _Card({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }
}
