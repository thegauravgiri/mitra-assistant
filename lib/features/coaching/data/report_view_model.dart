import '../../history/domain/models/meeting_session.dart';
import '../domain/models/goal.dart';
import '../domain/models/speaker_metrics.dart';
import 'goal_evaluator.dart';
import 'indicator_evaluator.dart';
import 'progress_service.dart';
import 'session_metrics.dart';

/// Everything the coaching report needs about "me" in one meeting, derived
/// from stored data. Pure, so the notifier (prompt input) and the UI
/// (scorecard) can never disagree.
class ReportViewModel {
  final SpeakerMetrics? me;
  final String? meName;
  final int speakerCount;
  final List<Indicator> indicators;
  final Map<String, double?> baselines; // indicator id -> avg of recent meetings
  final List<GoalResult> goals;
  final List<ProgressPoint> history; // my earlier meetings, oldest first

  const ReportViewModel({
    required this.me,
    required this.meName,
    required this.speakerCount,
    required this.indicators,
    required this.baselines,
    required this.goals,
    required this.history,
  });

  static ReportViewModel build(
    MeetingSession session,
    List<MeetingSession> allSessions,
    List<Goal> goals,
  ) {
    final metrics = metricsOf(session);
    final key = session.meSpeakerKey;
    final mine = key == null ? const <SpeakerMetrics>[] : metrics.where((m) => m.speakerKey == key).toList();
    if (mine.isEmpty) {
      return ReportViewModel(
        me: null,
        meName: key == null ? null : session.nameFor(key),
        speakerCount: metrics.length,
        indicators: const [],
        baselines: const {},
        goals: const [],
        history: const [],
      );
    }

    final name = session.nameFor(key!);
    final history = ProgressService.forPerson(
      allSessions.where((s) => s.id != session.id && s.startTime.isBefore(session.startTime)).toList(),
      name,
    );
    return ReportViewModel(
      me: mine.first,
      meName: name,
      speakerCount: metrics.length,
      indicators: IndicatorEvaluator.evaluate(mine.first, speakerCount: metrics.length),
      baselines: {for (final id in IndicatorEvaluator.ids) id: IndicatorEvaluator.baseline(id, history)},
      goals: [for (final g in goals) GoalEvaluator.evaluate(g, mine.first, speakerCount: metrics.length)],
      history: history,
    );
  }
}
