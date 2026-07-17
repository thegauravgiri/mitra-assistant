import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../providers/transcription_providers.dart';
import '../../../core/theme/app_theme.dart';

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
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(transcriptionNotifierProvider);

    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());

    if (state.entries.isEmpty && state.currentInterim.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Icon(Icons.mic_none_rounded, color: AppTheme.textMuted, size: 36),
              SizedBox(height: 12),
              Text(
                'Ready for Meeting',
                style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600, fontSize: 14),
              ),
              SizedBox(height: 4),
              Text(
                'Start a meeting to record system audio & mic transcription.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      itemCount: state.entries.length + (state.currentInterim.isNotEmpty ? 1 : 0),
      itemBuilder: (context, index) {
        if (index < state.entries.length) {
          final entry = state.entries[index];
          final timeStr = DateFormat('HH:mm:ss').format(entry.timestamp);

          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTheme.borderSubtle,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    timeStr,
                    style: const TextStyle(fontSize: 10, color: AppTheme.textMuted, fontFamily: 'monospace'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    entry.text,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppTheme.textPrimary,
                      height: 1.4,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          );
        } else {
          // Render Interim transcript line
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.graphic_eq, size: 14, color: AppTheme.primaryAccent),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    state.currentInterim,
                    style: TextStyle(
                      fontSize: 13,
                      color: AppTheme.primaryAccent.withValues(alpha: 0.9),
                      fontStyle: FontStyle.italic,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          );
        }
      },
    );
  }
}
