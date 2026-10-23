import 'package:flutter_test/flutter_test.dart';
import 'package:mitra_assistant/features/coaching/data/goal_evaluator.dart';
import 'package:mitra_assistant/features/coaching/data/indicator_evaluator.dart';
import 'package:mitra_assistant/features/coaching/data/participation_analyzer.dart';
import 'package:mitra_assistant/features/coaching/domain/models/goal.dart';
import 'package:mitra_assistant/features/coaching/domain/models/speaker_metrics.dart';
import 'package:mitra_assistant/features/transcription/domain/models/transcript_entry.dart';

TranscriptEntry e(String speaker, String text, double? s, double? en) => TranscriptEntry(
      id: '$speaker$text$s',
      text: text,
      timestamp: DateTime(2026),
      isFinal: true,
      speaker: speaker,
      startSec: s,
      endSec: en,
    );

String words(int n) => List.filled(n, 'word').join(' ');

void main() {
  group('fillers', () {
    test('counts um/uh/phrases and comma-delimited like, but not the verb', () {
      final c = ParticipationAnalyzer.countFillers(
        'Um, so basically it was, like, huge. You know, I mean, uh, I like it. Sort of.',
      );
      expect(c['um'], 1);
      expect(c['basically'], 1);
      expect(c['like'], 1); // only the comma-delimited one
      expect(c['you know'], 1);
      expect(c['i mean'], 1);
      expect(c['uh'], 1);
      expect(c['sort of'], 1);
    });
  });

  group('delivery metrics', () {
    // Speaker 1 talks 0-30s (60 words), Speaker 2 replies after 2s for 10s, S1 again.
    final entries = [
      e('Speaker 1', '${words(60)}?', 0, 30),
      e('Speaker 2', 'Um, ${words(20)} ?', 32, 42),
      e('Speaker 1', words(30), 43, 58),
    ];
    final m = ParticipationAnalyzer.analyze(entries);

    test('pace is words per minute of talk time', () {
      // S1: 90 words in 45 s = 120 wpm
      expect(m[0].paceWpm, closeTo(120, 0.5));
    });

    test('longest monologue and average turn use merged turns', () {
      expect(m[0].longestMonologueSec, 30);
      expect(m[0].avgTurnSec, closeTo(22.5, 0.01));
    });

    test('questions, fillers and response gap', () {
      expect(m[0].questionsAsked, 1);
      expect(m[1].questionsAsked, 1);
      expect(m[1].fillerCount, 1);
      expect(m[1].avgResponseGapSec, closeTo(2, 0.01)); // 32 - 30
      expect(m[0].avgResponseGapSec, closeTo(1, 0.01)); // 43 - 42
    });

    test('rates are null with too little talk time or no timings', () {
      final short = ParticipationAnalyzer.analyze([
        e('Speaker 1', 'Hi there', 0, 3),
        e('Speaker 2', 'Hello', 3.5, 4),
      ]);
      expect(short[0].paceWpm, isNull);
      expect(short[0].fillersPerMin, isNull);

      final untimed = ParticipationAnalyzer.analyze([e('Speaker 1', 'Hi', null, null)]);
      expect(untimed.single.longestMonologueSec, isNull);
      expect(untimed.single.avgResponseGapSec, isNull);
    });
  });

  group('indicators and goals', () {
    const strong = SpeakerMetrics(
      speakerKey: 'Speaker 1',
      talkTimeSec: 300,
      talkSharePct: 50,
      turnCount: 10,
      wordCount: 700,
      interruptionsMade: 0,
      interruptionsReceived: 1,
      paceWpm: 140,
      fillersPerMin: 1.5,
      longestMonologueSec: 40,
      questionsAsked: 3,
      avgResponseGapSec: 1.0,
    );
    const rough = SpeakerMetrics(
      speakerKey: 'Speaker 1',
      talkTimeSec: 300,
      talkSharePct: 85,
      turnCount: 3,
      wordCount: 900,
      interruptionsMade: 5,
      interruptionsReceived: 0,
      paceWpm: 210,
      fillersPerMin: 8,
      longestMonologueSec: 150,
      questionsAsked: 0,
      avgResponseGapSec: 4,
    );

    IndicatorStatus status(SpeakerMetrics m, String id) =>
        IndicatorEvaluator.evaluate(m, speakerCount: 2).firstWhere((i) => i.id == id).status;

    test('good and watch statuses follow the documented thresholds', () {
      for (final id in IndicatorEvaluator.ids) {
        expect(status(strong, id), IndicatorStatus.good, reason: id);
        expect(status(rough, id), IndicatorStatus.watch, reason: id);
      }
    });

    test('talk share is judged against the fair share for N speakers', () {
      // 50% with 4 speakers is 25 pts above the fair 25% -> ok, not good
      expect(
        IndicatorEvaluator.evaluate(strong, speakerCount: 4).firstWhere((i) => i.id == 'talkShare').status,
        IndicatorStatus.ok,
      );
    });

    test('unknown when a metric is not measurable', () {
      const untimed = SpeakerMetrics(
        speakerKey: 'S',
        talkTimeSec: 0,
        talkSharePct: 50,
        turnCount: 1,
        wordCount: 10,
        interruptionsMade: 0,
        interruptionsReceived: 0,
      );
      expect(status(untimed, 'pace'), IndicatorStatus.unknown);
      expect(status(untimed, 'questions'), IndicatorStatus.unknown); // < 30 words
    });

    test('goals are met or missed, and null when unmeasurable', () {
      expect(GoalEvaluator.evaluate(const Goal(GoalType.interruptions, 1), strong, speakerCount: 2).met, isTrue);
      expect(GoalEvaluator.evaluate(const Goal(GoalType.interruptions, 1), rough, speakerCount: 2).met, isFalse);
      expect(GoalEvaluator.evaluate(const Goal(GoalType.pace, 0), strong, speakerCount: 2).met, isTrue);
      expect(GoalEvaluator.evaluate(const Goal(GoalType.questions, 3), strong, speakerCount: 2).met, isTrue);
      expect(GoalEvaluator.evaluate(const Goal(GoalType.talkShare, 15), rough, speakerCount: 2).met, isFalse);
      const untimed = SpeakerMetrics(
        speakerKey: 'S',
        talkTimeSec: 0,
        talkSharePct: 50,
        turnCount: 1,
        wordCount: 10,
        interruptionsMade: 0,
        interruptionsReceived: 0,
      );
      expect(GoalEvaluator.evaluate(const Goal(GoalType.monologue, 60), untimed, speakerCount: 2).met, isNull);
    });

    test('goal JSON round-trips and ignores unknown types', () {
      final g = Goal.fromJson(const Goal(GoalType.fillers, 2).toJson())!;
      expect(g.type, GoalType.fillers);
      expect(g.target, 2);
      expect(Goal.fromJson({'type': 'nonsense'}), isNull);
    });

    test('SpeakerMetrics JSON round-trips the new fields and loads old JSON', () {
      final back = SpeakerMetrics.fromJson(strong.toJson());
      expect(back.paceWpm, 140);
      expect(back.questionsAsked, 3);
      final old = SpeakerMetrics.fromJson({'speakerKey': 'S', 'talkTimeSec': 5, 'talkSharePct': 10});
      expect(old.paceWpm, isNull);
      expect(old.fillerBreakdown, isEmpty);
    });
  });
}
