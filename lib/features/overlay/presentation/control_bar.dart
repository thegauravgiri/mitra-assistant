import 'dart:async';
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
import '../../../core/theme/design_tokens.dart';

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
  Timer? _elapsedTimer;
  String _elapsedString = '00:00';

  void _startTimer() {
    _elapsedTimer?.cancel();
    _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_meetingStartTime != null) {
        final duration = DateTime.now().difference(_meetingStartTime!);
        final mins = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
        final secs = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
        if (mounted) {
          setState(() {
            _elapsedString = '$mins:$secs';
          });
        }
      }
    });
  }

  void _stopTimer() {
    _elapsedTimer?.cancel();
    _elapsedTimer = null;
    if (mounted) {
      setState(() {
        _elapsedString = '00:00';
      });
    }
  }

  @override
  void dispose() {
    _elapsedTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final audioState = ref.watch(audioNotifierProvider);

    return GestureDetector(
      onPanStart: (_) => windowManager.startDragging(),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: const BoxDecoration(
          color: AppTheme.cardBackground,
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
          border: Border(
            bottom: BorderSide(color: AppTheme.borderSubtle, width: 1),
          ),
        ),
        child: Row(
          children: [
            // Drag handle & App Title
            const Icon(
              Icons.drag_indicator_rounded,
              color: AppTheme.textMuted,
              size: 16,
            ),
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
            
            // Elapsed Timer Badge if Recording
            if (audioState.isRecording) ...[
              const SizedBox(width: AppSpacing.sm),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.panicAccent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  border: Border.all(
                    color: AppTheme.panicAccent.withValues(alpha: 0.4),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: AppTheme.panicAccent,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _elapsedString,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.panicAccent,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const Spacer(),

            // Start / Stop Meeting Gradient Button
            Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () async {
                  if (audioState.isRecording) {
                    _stopTimer();

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
                      widget.onTabChanged(3); // Switch to Settings tab (Index 3)
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
                    _startTimer();

                    await ref
                        .read(transcriptionNotifierProvider.notifier)
                        .startTranscription();
                    ref.read(aiNotifierProvider.notifier).startPeriodicAnalysis();
                  }
                },
                child: AnimatedContainer(
                  duration: AppDuration.fast,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: audioState.isRecording
                          ? [const Color(0xFFEF4444), const Color(0xFFDC2626)]
                          : [const Color(0xFF6366F1), const Color(0xFF4F46E5)],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: (audioState.isRecording
                                ? AppTheme.panicAccent
                                : AppTheme.primaryAccent)
                            .withValues(alpha: 0.4),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        audioState.isRecording
                            ? Icons.stop_circle_rounded
                            : Icons.play_circle_fill_rounded,
                        size: 15,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        audioState.isRecording ? 'End Meeting' : 'Start Meeting',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(width: AppSpacing.xs + 2),

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

            const SizedBox(width: AppSpacing.xs + 2),

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
