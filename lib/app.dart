import 'package:flutter/material.dart';
import 'core/theme/app_theme.dart';
import 'features/overlay/presentation/overlay_shell.dart';

class MitraApp extends StatelessWidget {
  const MitraApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mitra Assistant',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: const OverlayShell(),
    );
  }
}
