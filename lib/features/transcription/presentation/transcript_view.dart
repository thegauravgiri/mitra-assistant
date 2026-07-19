import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../providers/transcription_providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../core/widgets/empty_state.dart';

class TranscriptView extends ConsumerStatefulWidget {
  const TranscriptView({super.key});

  @override
  ConsumerState<TranscriptView> createState() => _TranscriptViewState();
}

class _TranscriptViewState extends ConsumerState<TranscriptView> {
  final ScrollController _scrollController = ScrollController();

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: AppDuration.normal,
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(transcriptionNotifierProvider);

    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());

    if (state.entries.isEmpty && state.currentInterim.isEmpty) {
      return const EmptyStateWidget(
        icon: Icons.mic_none_rounded,
        title: 'Ready for Meeting',
        description: 'Start a meeting to record system audio & mic live speech transcription.',
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      itemCount: state.entries.length + (state.currentInterim.isNotEmpty ? 1 : 0),
      itemBuilder: (context, index) {
        if (index < state.entries.length) {
          final entry = state.entries[index];
          final timeStr = DateFormat('HH:mm:ss').format(entry.timestamp);

          return Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppTheme.cardBackground,
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(color: AppTheme.borderSubtle),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: AppTheme.borderSubtle.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(AppRadius.sm - 2),
                        ),
                        child: Text(
                          timeStr,
                          style: const TextStyle(
                            fontSize: 9,
                            color: AppTheme.textMuted,
                            fontFamily: 'monospace',
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    entry.text,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppTheme.textPrimary,
                      height: 1.45,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          );
        } else {
          // Render Interim transcript line with live waveform styling
          return Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppTheme.primaryAccent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(color: AppTheme.primaryAccent.withValues(alpha: 0.3)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.graphic_eq, size: 16, color: AppTheme.primaryAccent),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      state.currentInterim,
                      style: TextStyle(
                        fontSize: 13,
                        color: AppTheme.primaryAccent.withValues(alpha: 0.95),
                        fontStyle: FontStyle.italic,
                        height: 1.45,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }
      },
    );
  }
}
