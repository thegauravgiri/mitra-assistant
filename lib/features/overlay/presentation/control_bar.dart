import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';
import '../../audio/providers/audio_providers.dart';
import '../../transcription/providers/transcription_providers.dart';
import '../../ai_engine/providers/ai_providers.dart';
import '../../settings/providers/settings_providers.dart';
import '../../history/providers/history_providers.dart';
import '../data/window_control_service.dart';
import '../../../core/theme/app_theme.dart';

class ControlBar extends ConsumerStatefulWidget {
  final int activeTab;
  final ValueChanged<int> onTabChanged;
  final bool isCompact;
  final VoidCallback onToggleCompact;

  const ControlBar({
    super.key,
    required this.activeTab,
    required this.onTabChanged,
    required this.isCompact,
    required this.onToggleCompact,
  });

  @override
  ConsumerState<ControlBar> createState() => _ControlBarState();
}

class _ControlBarState extends ConsumerState<ControlBar> {
  DateTime? _meetingStartTime;

  @override
  Widget build(BuildContext context) {
    final audioState = ref.watch(audioNotifierProvider);

    return GestureDetector(
      onPanStart: (_) => windowManager.startDragging(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: const BoxDecoration(
          color: AppTheme.cardBackground,
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
          border: Border(
            bottom: BorderSide(color: AppTheme.borderSubtle, width: 1),
          ),
        ),
        child: Row(
          children: [
            // Drag handle & App Icon
            const Icon(
              Icons.drag_indicator_rounded,
              color: AppTheme.textMuted,
              size: 18,
            ),
            const SizedBox(width: 6),
            const Text(
              'Mitra Assistant',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
            const Spacer(),

            // Meeting Start / Stop Button
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: audioState.isRecording
                    ? AppTheme.panicAccent
                    : AppTheme.primaryAccent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              icon: Icon(
                audioState.isRecording
                    ? Icons.stop_rounded
                    : Icons.play_arrow_rounded,
                size: 14,
              ),
              label: Text(
                audioState.isRecording ? 'Stop' : 'Start Meeting',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
              onPressed: () async {
                if (audioState.isRecording) {
                  // Capture current session data before stopping
                  final transcriptState = ref.read(transcriptionNotifierProvider);
                  final aiState = ref.read(aiNotifierProvider);
                  final startTime = _meetingStartTime ?? DateTime.now();

                  // Stop analysis & audio services
                  ref.read(aiNotifierProvider.notifier).stopPeriodicAnalysis();
                  await ref
                      .read(transcriptionNotifierProvider.notifier)
                      .stopTranscription();
                  await ref
                      .read(audioNotifierProvider.notifier)
                      .stopRecording();

                  // Auto-generate title & summary from AI Insights
                  String meetingTitle = '';
                  String aiSummary = '';

                  if (aiState.insights.isNotEmpty) {
                    meetingTitle = aiState.insights.first.title;
                    final topDescriptions = aiState.insights
                        .take(2)
                        .map((i) => i.description)
                        .where((d) => d.trim().isNotEmpty);
                    aiSummary = topDescriptions.join(' ');
                  } else if (transcriptState.entries.isNotEmpty) {
                    final text = transcriptState.entries.first.text;
                    meetingTitle = text.length > 35 ? '${text.substring(0, 35)}...' : text;
                    aiSummary = text.length > 120 ? '${text.substring(0, 120)}...' : text;
                  }

                  // Save meeting session to history
                  if (transcriptState.entries.isNotEmpty) {
                    await ref.read(historyNotifierProvider.notifier).saveCurrentMeeting(
                          title: meetingTitle,
                          aiSummary: aiSummary,
                          startTime: startTime,
                          entries: transcriptState.entries,
                        );

                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Meeting saved to History tab.'),
                          duration: Duration(seconds: 2),
                          backgroundColor: AppTheme.secondaryAccent,
                        ),
                      );
                    }
                  }

                  // Reset local start time
                  _meetingStartTime = null;
                } else {
                  final settings = ref.read(settingsNotifierProvider);
                  if (settings.deepgramApiKey.trim().isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Please enter your Deepgram API Key in Settings to enable transcription.',
                        ),
                        backgroundColor: AppTheme.warningAccent,
                        duration: Duration(seconds: 3),
                      ),
                    );
                    widget.onTabChanged(2); // Switch to Settings tab
                    return;
                  }

                  final started = await ref
                      .read(audioNotifierProvider.notifier)
                      .startRecording();
                  if (!started) {
                    final audioState = ref.read(audioNotifierProvider);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            audioState.error ?? 'Microphone permission denied.',
                          ),
                          backgroundColor: AppTheme.warningAccent,
                          duration: const Duration(seconds: 5),
                          action: SnackBarAction(
                            label: 'Open Settings',
                            textColor: Colors.white,
                            onPressed: () {
                              ref
                                  .read(audioNotifierProvider.notifier)
                                  .openMicrophoneSettings();
                            },
                          ),
                        ),
                      );
                    }
                    return;
                  }

                  // Clear previous session state when starting a fresh meeting
                  ref.read(transcriptionNotifierProvider.notifier).clearTranscript();
                  ref.read(aiNotifierProvider.notifier).clearInsights();

                  _meetingStartTime = DateTime.now();

                  await ref
                      .read(transcriptionNotifierProvider.notifier)
                      .startTranscription();
                  ref.read(aiNotifierProvider.notifier).startPeriodicAnalysis();
                }
              },
            ),

            const SizedBox(width: 6),

            // Panic Hide Button
            IconButton(
              icon: const Icon(
                Icons.visibility_off_outlined,
                size: 16,
                color: AppTheme.warningAccent,
              ),
              tooltip: 'Panic Hide (⌘+Shift+H)',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onPressed: () async {
                await WindowControlService.instance.panicHide();
              },
            ),

            const SizedBox(width: 6),

            // Minimize / Compact Mode Toggle
            IconButton(
              icon: Icon(
                widget.isCompact
                    ? Icons.unfold_more_rounded
                    : Icons.unfold_less_rounded,
                size: 16,
                color: AppTheme.textSecondary,
              ),
              tooltip: widget.isCompact ? 'Expand Panel' : 'Compact Pill',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onPressed: widget.onToggleCompact,
            ),
          ],
        ),
      ),
    );
  }
}
