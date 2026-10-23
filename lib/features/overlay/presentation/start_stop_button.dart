import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../audio/providers/audio_providers.dart';
import '../../meeting/providers/meeting_providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/design_tokens.dart';

/// Start / End Meeting button shared by the Zen control bar and the Workspace.
class StartStopButton extends ConsumerWidget {
  /// Called when starting fails because an API key is missing.
  final VoidCallback onNeedSettings;

  const StartStopButton({super.key, required this.onNeedSettings});

  Future<void> _onTap(BuildContext context, WidgetRef ref) async {
    final meeting = ref.read(meetingNotifierProvider.notifier);
    final messenger = ScaffoldMessenger.of(context);

    if (ref.read(audioNotifierProvider).isRecording) {
      final saved = await meeting.stop();
      if (saved) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Meeting saved to History.'),
            duration: Duration(seconds: 2),
            backgroundColor: AppTheme.secondaryAccent,
          ),
        );
      }
      return;
    }

    switch (await meeting.start()) {
      case MeetingStartResult.started:
        break;
      case MeetingStartResult.missingDeepgramKey:
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Please enter your Deepgram API Key in Settings to enable transcription.'),
            backgroundColor: AppTheme.warningAccent,
            duration: Duration(seconds: 3),
          ),
        );
        onNeedSettings();
      case MeetingStartResult.audioFailed:
        messenger.showSnackBar(
          SnackBar(
            content: Text(ref.read(audioNotifierProvider).error ?? 'Microphone permission denied.'),
            backgroundColor: AppTheme.warningAccent,
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'Open Settings',
              textColor: Colors.white,
              onPressed: () => ref.read(audioNotifierProvider.notifier).openMicrophoneSettings(),
            ),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isRecording = ref.watch(audioNotifierProvider).isRecording;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => _onTap(context, ref),
        child: AnimatedContainer(
          duration: AppDuration.fast,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isRecording
                  ? [const Color(0xFFEF4444), const Color(0xFFDC2626)]
                  : [const Color(0xFF6366F1), const Color(0xFF4F46E5)],
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: (isRecording ? AppTheme.panicAccent : AppTheme.primaryAccent)
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
                isRecording ? Icons.stop_circle_rounded : Icons.play_circle_fill_rounded,
                size: 15,
                color: Colors.white,
              ),
              const SizedBox(width: 6),
              Text(
                isRecording ? 'End Meeting' : 'Start Meeting',
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
    );
  }
}

/// Red "● 01:23" badge shown while a meeting is running.
class ElapsedBadge extends ConsumerWidget {
  const ElapsedBadge({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(audioNotifierProvider).isRecording) return const SizedBox.shrink();
    final label = ref.watch(meetingNotifierProvider).elapsedLabel;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppTheme.panicAccent.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: AppTheme.panicAccent.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(color: AppTheme.panicAccent, shape: BoxShape.circle),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: AppTheme.panicAccent,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }
}
