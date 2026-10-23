import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../history/domain/models/meeting_session.dart';
import '../../history/providers/history_providers.dart';
import '../../settings/providers/settings_providers.dart';
import '../../transcription/domain/transcript_formatter.dart';
import '../../ai_engine/data/gemini_service.dart';
import '../data/coaching_feedback_service.dart';
import '../data/digest_service.dart';
import '../data/report_view_model.dart';
import '../data/session_metrics.dart';
import '../domain/models/coaching_report.dart';

class CoachingState {
  final Set<String> generating; // session ids with a review in flight
  final Map<String, String> errors; // session id -> last error
  final Set<String> digesting; // session ids with a digest in flight
  final int backfillDone;
  final int backfillTotal; // 0 = no backfill running

  const CoachingState({
    this.generating = const {},
    this.errors = const {},
    this.digesting = const {},
    this.backfillDone = 0,
    this.backfillTotal = 0,
  });

  bool get backfilling => backfillTotal > 0;

  CoachingState copyWith({
    Set<String>? generating,
    Map<String, String>? errors,
    Set<String>? digesting,
    int? backfillDone,
    int? backfillTotal,
  }) =>
      CoachingState(
        generating: generating ?? this.generating,
        errors: errors ?? this.errors,
        digesting: digesting ?? this.digesting,
        backfillDone: backfillDone ?? this.backfillDone,
        backfillTotal: backfillTotal ?? this.backfillTotal,
      );
}

class CoachingNotifier extends StateNotifier<CoachingState> {
  final Ref _ref;
  final GeminiService _gemini = GeminiService();

  CoachingNotifier(this._ref) : super(const CoachingState());

  /// Meeting notes (topics, decisions, actions, open questions) from Gemini.
  /// Feeds the Outcomes section and the cross-meeting graph. Returns true on
  /// success so a backfill can count failures.
  Future<bool> generateDigest(MeetingSession session) async {
    if (state.digesting.contains(session.id)) return false;
    final apiKey = _ref.read(settingsNotifierProvider).geminiApiKey;
    if (apiKey.trim().isEmpty) {
      _setError(session.id, 'Add your Gemini API key in Settings first.');
      return false;
    }

    state = state.copyWith(
      digesting: {...state.digesting, session.id},
      errors: {...state.errors}..remove(session.id),
    );
    try {
      final digest = await DigestService().generate(
        labelledTranscript: TranscriptFormatter.labelled(session.entries, nameFor: session.nameFor),
        generate: (system, prompt) => _gemini.generateStructured(
          apiKey: apiKey,
          systemPrompt: system,
          prompt: prompt,
        ),
      );
      await _updateLatest(session, (s) => s.copyWith(digest: digest));
      return true;
    } catch (e) {
      _setError(session.id, e.toString().replaceAll('Exception: ', ''));
      return false;
    } finally {
      state = state.copyWith(digesting: {...state.digesting}..remove(session.id));
    }
  }

  /// Builds digests for every saved meeting that has none, one at a time, so
  /// old conversations join the meeting graph. A failed meeting is skipped.
  Future<void> backfillDigests() async {
    if (state.backfilling) return;
    final pending = _ref
        .read(historyNotifierProvider)
        .sessions
        .where((s) => s.digest == null && s.entries.isNotEmpty)
        .toList();
    if (pending.isEmpty) return;

    state = state.copyWith(backfillDone: 0, backfillTotal: pending.length);
    for (final session in pending) {
      await generateDigest(session);
      state = state.copyWith(backfillDone: state.backfillDone + 1);
    }
    state = state.copyWith(backfillDone: 0, backfillTotal: 0);
  }

  /// Applies [change] to the freshest stored copy of a session (the user may
  /// have renamed speakers while Gemini was working).
  Future<void> _updateLatest(
    MeetingSession fallback,
    MeetingSession Function(MeetingSession) change,
  ) async {
    final latest = _ref
        .read(historyNotifierProvider)
        .sessions
        .firstWhere((s) => s.id == fallback.id, orElse: () => fallback);
    await _ref.read(historyNotifierProvider.notifier).updateSession(change(latest));
  }

  /// "This is me": names the speaker, remembers the choice for this meeting
  /// and (unless [coach] is false) asks for personalised coaching. [name] also becomes the profile name
  /// when none is set yet.
  Future<void> setMe(
    MeetingSession session,
    String speakerKey,
    String name, {
    bool coach = true,
  }) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    if (_ref.read(settingsNotifierProvider).myName.trim().isEmpty) {
      await _ref.read(settingsNotifierProvider.notifier).updateMyName(trimmed);
    }
    // One label per name inside a meeting, so progress never double-counts.
    final names = {
      for (final e in session.speakerNames.entries)
        if (e.value.trim().toLowerCase() != trimmed.toLowerCase()) e.key: e.value,
      speakerKey: trimmed,
    };
    final updated = session.copyWith(
      speakerNames: names,
      meSpeakerKey: speakerKey,
      // meetings saved before reports existed get one now, so it is stored
      coachingReport: session.coachingReport ??
          CoachingReport(metrics: metricsOf(session), generatedAt: DateTime.now()),
    );
    await _ref.read(historyNotifierProvider.notifier).updateSession(updated);
    if (coach) await generateCoaching(updated);
  }

  /// Personalised strengths / improvements for the user in [session].
  Future<void> generateCoaching(MeetingSession session) async {
    final me = session.meSpeakerKey;
    if (me == null) return;
    if (state.generating.contains(session.id)) return;
    final apiKey = _ref.read(settingsNotifierProvider).geminiApiKey;
    if (apiKey.trim().isEmpty) {
      _setError(session.id, 'Add your Gemini API key in Settings first.');
      return;
    }
    final metrics = metricsOf(session);
    final mine = metrics.where((m) => m.speakerKey == me);
    if (mine.isEmpty) {
      _setError(session.id, 'No speech was found for the selected speaker.');
      return;
    }

    state = state.copyWith(
      generating: {...state.generating, session.id},
      errors: {...state.errors}..remove(session.id),
    );
    try {
      final vm = ReportViewModel.build(
        session,
        _ref.read(historyNotifierProvider).sessions,
        _ref.read(settingsNotifierProvider).goals,
      );
      final name = vm.meName ?? session.nameFor(me);

      final feedback = await CoachingFeedbackService().generate(
        name: name,
        myText: session.entries.where((e) => e.speaker == me).map((e) => e.text).join(' '),
        labelledTranscript: TranscriptFormatter.labelled(session.entries, nameFor: session.nameFor),
        meetingOverview: session.digest?.summary ?? '',
        summary: CoachingFeedbackService.summarize(
          indicators: vm.indicators,
          baselines: vm.baselines,
          goals: vm.goals,
        ),
        generate: (system, prompt) => _gemini.generateStructured(
          apiKey: apiKey,
          systemPrompt: system,
          prompt: prompt,
          temperature: 0.4,
        ),
      );
      await _updateLatest(session, (s) => s.copyWith(feedback: feedback));
    } catch (e) {
      _setError(session.id, e.toString().replaceAll('Exception: ', ''));
    } finally {
      state = state.copyWith(generating: {...state.generating}..remove(session.id));
    }
  }

  /// Maps a diarised label to a real name. An empty name clears the mapping.
  Future<void> renameSpeaker(
    MeetingSession session,
    String speakerKey,
    String name,
  ) async {
    final names = {...session.speakerNames};
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      names.remove(speakerKey);
    } else {
      names[speakerKey] = trimmed;
    }
    await _ref
        .read(historyNotifierProvider.notifier)
        .updateSession(session.copyWith(speakerNames: names));
  }

  void _setError(String id, String message) {
    state = state.copyWith(errors: {...state.errors, id: message});
  }
}

final coachingNotifierProvider =
    StateNotifierProvider<CoachingNotifier, CoachingState>((ref) {
  return CoachingNotifier(ref);
});
