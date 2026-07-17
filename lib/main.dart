import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';
import 'features/overlay/data/window_control_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize overlay window settings and hotkeys
  await WindowControlService.instance.initializeWindow();

  runApp(
    const ProviderScope(
      child: MitraApp(),
    ),
  );
}
