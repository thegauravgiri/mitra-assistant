import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';
import '../../audio/providers/audio_providers.dart';
import '../../transcription/providers/transcription_providers.dart';
import '../../ai_engine/providers/ai_providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../core/widgets/status_indicator.dart';

class CompactModeView extends ConsumerWidget {
  final VoidCallback onExpand;

  const CompactModeView({super.key, required this.onExpand});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final audioState = ref.watch(audioNotifierProvider);
    final transcriptState = ref.watch(transcriptionNotifierProvider);
    final aiState = ref.watch(aiNotifierProvider);

    String displayText = 'Mitra Assistant Idle';
    if (transcriptState.currentInterim.isNotEmpty) {
      displayText = transcriptState.currentInterim;
    } else if (aiState.insights.isNotEmpty) {
      displayText = '💡 ${aiState.insights.first.title}: ${aiState.insights.first.description}';
    } else if (transcriptState.entries.isNotEmpty) {
      displayText = transcriptState.entries.last.text;
    }

    return GestureDetector(
      onPanStart: (_) => windowManager.startDragging(),
      onDoubleTap: onExpand,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
        decoration: BoxDecoration(
          color: AppTheme.backgroundDark,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(
            color: audioState.isRecording
                ? AppTheme.secondaryAccent.withValues(alpha: 0.6)
                : AppTheme.primaryAccent.withValues(alpha: 0.5),
            width: 1.5,
          ),
          boxShadow: AppShadows.medium,
        ),
        child: Row(
          children: [
            StatusIndicator(
              isActive: audioState.isRecording,
              label: '',
              activeColor: AppTheme.secondaryAccent,
              inactiveColor: AppTheme.textMuted,
              dotSize: 8,
            ),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: Text(
                displayText,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.w500,
                  letterSpacing: -0.1,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            IconButton(
              icon: const Icon(
                Icons.open_in_full_rounded,
                size: 14,
                color: AppTheme.primaryAccent,
              ),
              tooltip: 'Expand Panel',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onPressed: onExpand,
            ),
          ],
        ),
      ),
    );
  }
}
