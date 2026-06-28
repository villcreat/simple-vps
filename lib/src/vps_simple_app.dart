import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'app_controller.dart';
import 'app_strings.dart';
import 'app_theme.dart';
import 'screens/home_shell.dart';
import 'screens/lock_screen.dart';

class VpsSimpleApp extends StatelessWidget {
  const VpsSimpleApp({
    required this.controller,
    super.key,
  });

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'VPS Simple',
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          themeMode: controller.themeMode,
          locale: controller.locale,
          supportedLocales: AppStrings.supportedLocales,
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          builder: (context, child) {
            // Reset the idle auto-lock timer on any pointer interaction.
            return Listener(
              behavior: HitTestBehavior.translucent,
              onPointerDown: (_) => controller.registerActivity(),
              onPointerMove: (_) => controller.registerActivity(),
              onPointerSignal: (_) => controller.registerActivity(),
              child: child ?? const SizedBox.shrink(),
            );
          },
          home: controller.isUnlocked
              ? HomeShell(controller: controller)
              : LockScreen(controller: controller),
        );
      },
    );
  }
}
