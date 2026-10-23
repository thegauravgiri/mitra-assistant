import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../ai_engine/providers/ai_providers.dart';
import '../../audio/providers/audio_providers.dart';
import '../../coaching/providers/coaching_providers.dart';
import '../../history/data/meeting_identity.dart';
import '../../history/providers/history_providers.dart';
import '../../settings/providers/settings_providers.dart';
import '../../transcription/providers/transcription_providers.dart';

enum MeetingStartResult { started, missingDeepgramKey, audioFailed }

class MeetingState {
  final DateTime? startTime;
  final Duration elapsed;

  const MeetingState({this.startTime, this.elapsed = Duration.zero});

  bool get isActive => startTime != null;

  /// mm:ss, as shown in the control bar.
  String get elapsedLabel {
    final m = elapsed.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = elapsed.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}

/// Owns the meeting lifecycle (start, timer, stop + save) so it survives UI
/// changes such as switching between the Zen window and the Workspace.
class MeetingNotifier extends StateNotifier<MeetingState> {
  final Ref _ref;
  Timer? _timer;

  MeetingNotifier(this._ref) : super(const MeetingState());

  Future<MeetingStartResult> start() async {
    if (_ref.read(settingsNotifierProvider).deepgramApiKey.trim().isEmpty) {
      return MeetingStartResult.missingDeepgramKey;
    }

    final started = await _ref.read(audioNotifierProvider.notifier).startRecording();
    if (!started) return MeetingStartResult.audioFailed;

    // Clear previous session state when starting a fresh meeting
    _ref.read(transcriptionNotifierProvider.notifier).clearTranscript();
    _ref.read(aiNotifierProvider.notifier).clearInsights();

    final startTime = DateTime.now();
    state = MeetingState(startTime: startTime);
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      final start = state.startTime;
      if (start != null) {
        state = MeetingState(startTime: start, elapsed: DateTime.now().difference(start));
      }
    });

    await _ref.read(transcriptionNotifierProvider.notifier).startTranscription();
    _ref.read(aiNotifierProvider.notifier).startPeriodicAnalysis();
    return MeetingStartResult.started;
  }

  /// Stops capture, saves the meeting to history and kicks off the written
  /// coaching review in the background. Returns true if a meeting was saved.
  Future<bool> stop() async {
    _timer?.cancel();
    _timer = null;

    // Capture current session data before stopping
    final transcriptState = _ref.read(transcriptionNotifierProvider);
    final aiState = _ref.read(aiNotifierProvider);
    final startTime = state.startTime ?? DateTime.now();
    state = const MeetingState();

    _ref.read(aiNotifierProvider.notifier).stopPeriodicAnalysis();
    await _ref.read(transcriptionNotifierProvider.notifier).stopTranscription();
    await _ref.read(audioNotifierProvider.notifier).stopRecording();

    if (transcriptState.entries.isEmpty) return false;

    // Auto-generate title & summary from AI Insights
    String meetingTitle = '';
    String aiSummary = '';
    if (aiState.insights.isNotEmpty) {
      meetingTitle = aiState.insights.first.title;
      aiSummary = aiState.insights
          .take(2)
          .map((i) => i.description)
          .where((d) => d.trim().isNotEmpty)
          .join(' ');
    } else {
      final text = transcriptState.entries.first.text;
      meetingTitle = text.length > 35 ? '${text.substring(0, 35)}...' : text;
      aiSummary = text.length > 120 ? '${text.substring(0, 120)}...' : text;
    }

    // Mic on its own channel = the user is "You": no manual "which speaker am I?"
    final identity = MeetingIdentity.forEntries(
      transcriptState.entries,
      _ref.read(settingsNotifierProvider).myName,
    );
    final saved = await _ref.read(historyNotifierProvider.notifier).saveCurrentMeeting(
          title: meetingTitle,
          aiSummary: aiSummary,
          startTime: startTime,
          entries: transcriptState.entries,
          insights: aiState.insights,
          meSpeakerKey: identity.meKey,
          speakerNames: identity.names,
        );
    // Metrics are saved already; the notes (and so the graph) arrive shortly after.
    if (saved != null) {
      _ref.read(coachingNotifierProvider.notifier).generateDigest(saved);
    }
    return saved != null;
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

final meetingNotifierProvider =
    StateNotifierProvider<MeetingNotifier, MeetingState>((ref) {
  return MeetingNotifier(ref);
});
