import 'package:flutter/material.dart';

import 'src/app_controller.dart';
import 'src/vps_simple_app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final controller = AppController();
  await controller.load();

  runApp(VpsSimpleApp(controller: controller));
}
