import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../theme/design_tokens.dart';

/// "Are you sure?" with a checkbox the user must tick before the delete
/// button works. Returns true only when they ticked it and pressed delete.
Future<bool> confirmDelete(
  BuildContext context, {
  required String title,
  required String message,
  String checkboxLabel = 'I understand this cannot be undone',
  String confirmLabel = 'Delete',
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (_) => _ConfirmDeleteDialog(
      title: title,
      message: message,
      checkboxLabel: checkboxLabel,
      confirmLabel: confirmLabel,
    ),
  );
  return result ?? false;
}

class _ConfirmDeleteDialog extends StatefulWidget {
  final String title;
  final String message;
  final String checkboxLabel;
  final String confirmLabel;

  const _ConfirmDeleteDialog({
    required this.title,
    required this.message,
    required this.checkboxLabel,
    required this.confirmLabel,
  });

  @override
  State<_ConfirmDeleteDialog> createState() => _ConfirmDeleteDialogState();
}

class _ConfirmDeleteDialogState extends State<_ConfirmDeleteDialog> {
  bool _confirmed = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppTheme.backgroundPureDark,
      title: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: AppTheme.panicAccent, size: 20),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: Text(widget.title, style: const TextStyle(fontSize: 15, color: AppTheme.textPrimary))),
        ],
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.message, style: const TextStyle(fontSize: 12.5, color: AppTheme.textSecondary, height: 1.45)),
            const SizedBox(height: AppSpacing.md),
            InkWell(
              borderRadius: BorderRadius.circular(AppRadius.sm),
              onTap: () => setState(() => _confirmed = !_confirmed),
              child: Row(
                children: [
                  Checkbox(
                    value: _confirmed,
                    onChanged: (v) => setState(() => _confirmed = v ?? false),
                    visualDensity: VisualDensity.compact,
                  ),
                  Expanded(
                    child: Text(widget.checkboxLabel, style: const TextStyle(fontSize: 12.5, color: AppTheme.textPrimary)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
        FilledButton(
          // stays disabled until the box is ticked
          onPressed: _confirmed ? () => Navigator.of(context).pop(true) : null,
          style: FilledButton.styleFrom(
            backgroundColor: AppTheme.panicAccent,
            disabledBackgroundColor: AppTheme.panicAccent.withValues(alpha: 0.25),
          ),
          child: Text(widget.confirmLabel),
        ),
      ],
    );
  }
}
