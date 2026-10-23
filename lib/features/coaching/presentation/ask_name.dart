import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

/// Asks for the user's name (shown once, then remembered in Settings).
Future<String?> askMyName(BuildContext context) {
  final c = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: AppTheme.backgroundPureDark,
      title: const Text('What should we call you?', style: TextStyle(fontSize: 14)),
      content: TextField(
        controller: c,
        autofocus: true,
        decoration: const InputDecoration(hintText: 'e.g. John'),
        onSubmitted: (v) => Navigator.of(ctx).pop(v),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.of(ctx).pop(c.text), child: const Text('Save')),
      ],
    ),
  );
}
