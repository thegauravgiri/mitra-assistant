import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';
import '../../audio/providers/audio_providers.dart';
import '../../transcription/providers/transcription_providers.dart';
import '../../ai_engine/providers/ai_providers.dart';
import '../../../core/theme/app_theme.dart';

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
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: AppTheme.backgroundDark,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppTheme.primaryAccent.withValues(alpha: 0.5), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.4),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: audioState.isRecording ? AppTheme.secondaryAccent : AppTheme.textMuted,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                displayText,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, color: AppTheme.textPrimary, fontWeight: FontWeight.w500),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.open_in_full_rounded, size: 14, color: AppTheme.primaryAccent),
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
