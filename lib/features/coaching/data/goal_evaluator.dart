import '../../../core/constants/app_constants.dart';
import '../domain/models/goal.dart';
import '../domain/models/speaker_metrics.dart';
import 'indicator_evaluator.dart';

class GoalResult {
  final Goal goal;

  /// null = could not be measured for this meeting (e.g. no word timings).
  final bool? met;
  final String valueText;

  const GoalResult(this.goal, this.met, this.valueText);
}

class GoalEvaluator {
  static GoalResult evaluate(Goal goal, SpeakerMetrics m, {required int speakerCount}) {
    String id;
    switch (goal.type) {
      case GoalType.interruptions:
        id = 'interruptions';
      case GoalType.monologue:
        id = 'monologue';
      case GoalType.questions:
        id = 'questions';
      case GoalType.fillers:
        id = 'fillers';
      case GoalType.talkShare:
        id = 'talkShare';
      case GoalType.pace:
        id = 'pace';
    }
    final v = IndicatorEvaluator.valueOf(id, m, speakerCount);
    if (v == null) return GoalResult(goal, null, 'n/a');

    bool met;
    String text;
    switch (goal.type) {
      case GoalType.interruptions:
        met = v <= goal.target;
        text = '${v.toStringAsFixed(0)}x';
      case GoalType.monologue:
        met = v <= goal.target;
        text = '${v.toStringAsFixed(0)} s';
      case GoalType.questions:
        met = v >= goal.target;
        text = v.toStringAsFixed(0);
      case GoalType.fillers:
        met = v <= goal.target;
        text = '${v.toStringAsFixed(1)} /min';
      case GoalType.talkShare:
        met = v.abs() <= goal.target;
        text = '${m.talkSharePct.toStringAsFixed(0)}%';
      case GoalType.pace:
        met = v >= AppConstants.paceGoodMinWpm && v <= AppConstants.paceGoodMaxWpm;
        text = '${v.toStringAsFixed(0)} wpm';
    }
    return GoalResult(goal, met, text);
  }
}
