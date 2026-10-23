import 'package:flutter_test/flutter_test.dart';
import 'package:mitra_assistant/features/coaching/data/coaching_feedback_service.dart';
import 'package:mitra_assistant/features/coaching/data/goal_evaluator.dart';
import 'package:mitra_assistant/features/coaching/data/indicator_evaluator.dart';
import 'package:mitra_assistant/features/coaching/domain/models/goal.dart';
import 'package:mitra_assistant/features/coaching/domain/models/speaker_metrics.dart';

const myText = "Let's lock the budget today. I think we should ship on Friday, and then review the rollout plan.";

String json({String strengthQuote = 'we should ship on Friday', String improveQuote = 'review the rollout plan'}) => '''
{"strengths":[{"title":"Clear proposal","evidence":"$strengthQuote"},{"title":"Decisive","evidence":""},{"title":"third","evidence":""}],
 "improvements":[{"title":"Pause more","evidence":"$improveQuote","tip":"Wait two seconds after a question."}],
 "goalNotes":["Interruptions goal met."]}
''';

void main() {
  group('CoachingFeedbackService.parse', () {
    test('keeps verbatim quotes (case and punctuation insensitive)', () {
      final f = CoachingFeedbackService.parse(json(), myText: myText)!;
      expect(f.strengths.first.evidence, 'we should ship on Friday');
      expect(f.improvements.single.evidence, 'review the rollout plan');
      expect(f.improvements.single.tip, contains('two seconds'));
      expect(f.goalNotes, ['Interruptions goal met.']);
    });

    test('drops invented quotes but keeps the item', () {
      final f = CoachingFeedbackService.parse(
        json(strengthQuote: 'we absolutely must ship tomorrow'),
        myText: myText,
      )!;
      expect(f.strengths.first.title, 'Clear proposal');
      expect(f.strengths.first.evidence, isNull);
    });

    test('drops over-long quotes and caps strengths at 2', () {
      final longQuote = List.filled(25, 'budget').join(' ');
      final f = CoachingFeedbackService.parse(
        json(improveQuote: longQuote),
        myText: '$myText $longQuote',
      )!;
      expect(f.improvements.single.evidence, isNull);
      expect(f.strengths.length, 2);
    });

    test('handles fences, prose, garbage and empty feedback', () {
      expect(CoachingFeedbackService.parse('```json\n${json()}\n```', myText: myText), isNotNull);
      expect(CoachingFeedbackService.parse('Sure: ${json()}', myText: myText), isNotNull);
      expect(CoachingFeedbackService.parse('nope', myText: myText), isNull);
      expect(CoachingFeedbackService.parse('{"strengths":[],"improvements":[]}', myText: myText), isNull);
    });
  });

  test('summarize lists indicators with baseline and goal outcomes', () {
    const m = SpeakerMetrics(
      speakerKey: 'S',
      talkTimeSec: 120,
      talkSharePct: 70,
      turnCount: 4,
      wordCount: 300,
      interruptionsMade: 4,
      interruptionsReceived: 0,
      paceWpm: 150,
    );
    final text = CoachingFeedbackService.summarize(
      indicators: IndicatorEvaluator.evaluate(m, speakerCount: 2),
      baselines: {'pace': 135.0},
      goals: [GoalEvaluator.evaluate(const Goal(GoalType.interruptions, 1), m, speakerCount: 2)],
    );
    expect(text, contains('Speaking pace: 150 wpm'));
    expect(text, contains('average over recent meetings: 135.0'));
    expect(text, contains('NOT met'));
    expect(text, contains('Interrupted others: 4x (watch'));
  });

  test('generate uses the injected model and throws on unusable output', () async {
    final ok = await CoachingFeedbackService().generate(
      name: 'Sneha',
      myText: myText,
      labelledTranscript: 'Sneha: $myText',
      summary: 's',
      generate: (system, prompt) async {
        expect(prompt, contains('Coachee: Sneha'));
        return json();
      },
    );
    expect(ok.strengths, isNotEmpty);
    expect(
      () => CoachingFeedbackService().generate(
        name: 'S',
        myText: '',
        labelledTranscript: '',
        summary: '',
        generate: (_, _) async => 'nope',
      ),
      throwsException,
    );
  });
}
