import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import '../data/window_control_service.dart';
import 'start_stop_button.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/design_tokens.dart';

/// Top bar of the Zen window: drag handle, meeting controls, panic hide,
/// compact toggle and a button that opens the Workspace.
class ControlBar extends StatelessWidget {
  final bool isCompact;
  final VoidCallback onToggleCompact;
  final VoidCallback onOpenWorkspace;
  final VoidCallback onNeedSettings;

  const ControlBar({
    super.key,
    required this.isCompact,
    required this.onToggleCompact,
    required this.onOpenWorkspace,
    required this.onNeedSettings,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanStart: (_) => windowManager.startDragging(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
        decoration: const BoxDecoration(
          color: AppTheme.cardBackground,
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
          border: Border(bottom: BorderSide(color: AppTheme.borderSubtle, width: 1)),
        ),
        child: Row(
          children: [
            const Icon(Icons.drag_indicator_rounded, color: AppTheme.textMuted, size: 16),
            const SizedBox(width: AppSpacing.xs),
            const Text(
              'Mitra Assistant',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            const ElapsedBadge(),
            const Spacer(),
            StartStopButton(onNeedSettings: onNeedSettings),
            const SizedBox(width: AppSpacing.xs + 2),
            IconButton(
              icon: const Icon(Icons.visibility_off_outlined, size: 16, color: AppTheme.warningAccent),
              tooltip: 'Panic Hide (⌘/Ctrl+Shift+H)',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onPressed: () => WindowControlService.instance.panicHide(),
            ),
            const SizedBox(width: AppSpacing.xs + 2),
            IconButton(
              icon: const Icon(Icons.dashboard_customize_rounded, size: 16, color: AppTheme.primaryAccent),
              tooltip: 'Open Workspace',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onPressed: onOpenWorkspace,
            ),
            const SizedBox(width: AppSpacing.xs + 2),
            IconButton(
              icon: Icon(
                isCompact ? Icons.unfold_more_rounded : Icons.unfold_less_rounded,
                size: 16,
                color: AppTheme.textSecondary,
              ),
              tooltip: isCompact ? 'Expand Panel' : 'Compact Pill',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onPressed: onToggleCompact,
            ),
          ],
        ),
      ),
    );
  }
}
