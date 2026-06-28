import 'package:flutter/material.dart';

import '../app_controller.dart';
import '../app_strings.dart';

class LockScreen extends StatefulWidget {
  const LockScreen({
    required this.controller,
    super.key,
  });

  final AppController controller;

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  final _passwordController = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final strings = AppStrings(widget.controller.locale);
        final needsSetup = widget.controller.needsSetup;
        final error = widget.controller.unlockError;
        final errorText = switch (error) {
          UnlockError.empty => strings.t('required'),
          UnlockError.wrongPassword => strings.t('wrongPassword'),
          null => null,
        };

        return Scaffold(
          body: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Icon(
                      Icons.dns_rounded,
                      size: 56,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'VPS Simple',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      needsSetup
                          ? strings.t('setupHint')
                          : strings.t('appSubtitle'),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 24),
                    TextField(
                      controller: _passwordController,
                      obscureText: true,
                      autofocus: true,
                      enabled: !_busy,
                      decoration: InputDecoration(
                        labelText: strings.t('masterPassword'),
                        prefixIcon: const Icon(Icons.lock_outline),
                        errorText: errorText,
                      ),
                      onSubmitted: (_) => _submit(),
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: _busy ? null : _submit,
                      icon: Icon(
                        needsSetup ? Icons.key : Icons.lock_open,
                      ),
                      label: Text(
                        needsSetup
                            ? strings.t('createMasterPassword')
                            : strings.t('unlock'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _submit() async {
    setState(() => _busy = true);
    await widget.controller.unlockOrSetup(_passwordController.text);
    if (mounted) {
      setState(() => _busy = false);
    }
  }
}
