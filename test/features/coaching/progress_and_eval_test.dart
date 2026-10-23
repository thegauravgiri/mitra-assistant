import 'package:flutter_test/flutter_test.dart';
import 'package:mitra_assistant/features/ai_engine/domain/models/insight.dart';
import 'package:mitra_assistant/features/coaching/data/progress_service.dart';
import 'package:mitra_assistant/features/coaching/data/report_export_service.dart';
import 'package:mitra_assistant/features/coaching/data/session_evaluator.dart';
import 'package:mitra_assistant/features/coaching/domain/models/coaching_feedback.dart';
import 'package:mitra_assistant/features/coaching/domain/models/coaching_report.dart';
import 'package:mitra_assistant/features/coaching/domain/models/meeting_digest.dart';
import 'package:mitra_assistant/features/coaching/domain/models/speaker_metrics.dart';
import 'package:mitra_assistant/features/history/domain/models/meeting_session.dart';

SpeakerMetrics m(String key, double talk, double share) => SpeakerMetrics(
      speakerKey: key,
      talkTimeSec: talk,
      talkSharePct: share,
      turnCount: 3,
      wordCount: 50,
      interruptionsMade: 1,
      interruptionsReceived: 0,
    );

MeetingSession session(
  String id,
  DateTime start, {
  Map<String, String> names = const {},
  List<SpeakerMetrics> metrics = const [],
  List<Insight> insights = const [],
}) =>
    MeetingSession(
      id: id,
      title: 'Meeting $id',
      aiSummary: '',
      startTime: start,
      endTime: start.add(const Duration(minutes: 10)),
      entries: const [],
      speakerNames: names,
      insights: insights,
      coachingReport: CoachingReport(
        metrics: metrics,
        reviews: const {'Speaker 1': 'Good pace.'},
        generatedAt: start,
      ),
    );

Insight unanswered(String desc, {int? latency}) => Insight(
      id: desc,
      category: InsightCategory.unansweredQuestion,
      title: 'Speaker 2 asked',
      description: desc,
      timestamp: DateTime(2026),
      latencyMs: latency,
    );

void main() {
  group('ProgressService', () {
    final older = session('a', DateTime(2026, 9, 1),
        names: {'Speaker 1': 'Sneha'}, metrics: [m('Speaker 1', 60, 60)]);
    final newer = session('b', DateTime(2026, 9, 8),
        names: {'Speaker 2': ' sneha '}, metrics: [m('Speaker 2', 40, 40)]);
    final other = session('c', DateTime(2026, 9, 9),
        names: {'Speaker 1': 'Raj'}, metrics: [m('Speaker 1', 10, 10)]);

    test('matches names case-insensitively across different labels, oldest first', () {
      final pts = ProgressService.forPerson([newer, other, older], 'SNEHA');
      expect(pts.map((p) => p.session.id), ['a', 'b']);
      expect(pts.last.metrics.talkSharePct, 40);
    });

    test('knownNames dedupes by normalised name', () {
      expect(ProgressService.knownNames([older, newer, other]), ['Raj', 'Sneha']);
    });

    test('unnamed or report-less sessions contribute nothing', () {
      expect(ProgressService.forPerson([session('d', DateTime(2026))], 'Sneha'), isEmpty);
    });
  });

  group('SessionEvaluator', () {
    test('talk-time error, recall/precision and latency', () {
      final s = session(
        'e',
        DateTime(2026, 9, 1),
        metrics: [m('Speaker 1', 66, 60), m('Speaker 2', 30, 40)],
        insights: [
          unanswered('What does the licence cost for teams?', latency: 8000),
          unanswered('Totally unrelated flagged thing', latency: 20000),
        ],
      );
      final r = SessionEvaluator.evaluate(s, {
        'talkSeconds': {'Speaker 1': 60.0, 'Speaker 2': 40.0},
        'unansweredQuestions': [
          'What does the licence cost?',
          'When is the deadline for delivery?',
        ],
      });
      expect(r.talkTime['Speaker 1']!.error, closeTo(0.10, 1e-9));
      expect(r.talkTime['Speaker 2']!.error, closeTo(0.25, 1e-9));
      expect(r.matchedUnanswered, 1);
      expect(r.recall, 0.5);
      expect(r.precision, 0.5);
      expect(r.percentileLatency(0.5), anyOf(8000, 20000));
      expect(r.shareWithin15s, 0.5);
      expect(r.report(), contains('recall: 50%'));
    });
  });

  group('ReportExportService.buildMarkdown', () {
    test('includes table, reviews using renamed speakers, and unanswered questions', () {
      final s = session(
        'f',
        DateTime(2026, 9, 1),
        names: {'Speaker 1': 'Sneha'},
        metrics: [m('Speaker 1', 60, 100)],
        insights: [unanswered('Who owns the rollout?')],
      );
      final md = ReportExportService.buildMarkdown(s);
      expect(md, contains('| Sneha | 100% |'));
      expect(md, contains('### Sneha'));
      expect(md, contains('Good pace.'));
      expect(md, contains('## Unanswered questions'));
      expect(md, contains('Who owns the rollout?'));
    });

    test('includes coaching feedback and meeting notes when present', () {
      final base = session('g', DateTime(2026, 9, 1), names: {'Speaker 1': 'Sneha'}, metrics: [m('Speaker 1', 60, 100)]);
      final s = base.copyWith(
        meSpeakerKey: 'Speaker 1',
        feedback: CoachingFeedback(
          strengths: const [FeedbackItem('Clear proposal', evidence: 'we should ship')],
          improvements: const [FeedbackItem('Pause more', tip: 'Wait two seconds')],
          generatedAt: DateTime(2026),
        ),
        digest: MeetingDigest(
          summary: 'Shipping plan agreed.',
          decisions: const [DigestDecision('Ship Friday')],
          actionItems: const [DigestAction('Send notes', owner: 'Raj')],
          openQuestions: const [DigestQuestion('Who tests?', asker: 'Sneha')],
          generatedAt: DateTime(2026),
        ),
      );
      final md = ReportExportService.buildMarkdown(s);
      expect(md, contains('## Coaching for Sneha'));
      expect(md, contains('Said: "we should ship"'));
      expect(md, contains('Try: Wait two seconds'));
      expect(md, contains('## Meeting notes'));
      expect(md, contains('- Raj: Send notes'));
      expect(md, contains('- Sneha asked: Who tests?'));
    });
  });
}
