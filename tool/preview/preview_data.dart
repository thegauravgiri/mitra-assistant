// Sample data for screenshots of the UI. Never used by the real app.
import 'dart:convert';
import 'package:mitra_assistant/core/constants/app_constants.dart';
import 'package:mitra_assistant/features/coaching/data/participation_analyzer.dart';
import 'package:mitra_assistant/features/coaching/domain/models/coaching_feedback.dart';
import 'package:mitra_assistant/features/coaching/domain/models/coaching_report.dart';
import 'package:mitra_assistant/features/coaching/domain/models/goal.dart';
import 'package:mitra_assistant/features/coaching/domain/models/meeting_digest.dart';
import 'package:mitra_assistant/features/documents/domain/models/doc_graph.dart';
import 'package:mitra_assistant/features/documents/domain/models/uploaded_document.dart';
import 'package:mitra_assistant/features/history/domain/models/meeting_session.dart';
import 'package:mitra_assistant/features/transcription/domain/models/transcript_entry.dart';
import 'package:mitra_assistant/core/utils/text_similarity.dart';

String _words(int n) => List.filled(n, 'word').join(' ');

MeetingSession _meeting(
  String id,
  DateTime start,
  String title, {
  required MeetingDigest digest,
  bool me = false,
  double s1Share = 0.55,
}) {
  var t = 0.0;
  final entries = <TranscriptEntry>[];
  void say(int sp, String text, double dur) {
    entries.add(TranscriptEntry(
      id: '$id$t',
      text: text,
      timestamp: start,
      isFinal: true,
      speaker: 'Speaker ${sp + 1}',
      speakerIndex: sp,
      startSec: t,
      endSec: t + dur,
    ));
    t += dur + 0.8;
  }

  say(0, 'So basically we should lock the budget this week. ${_words(60)}', 40 * s1Share * 2);
  say(1, 'Can we check the forecast first? ${_words(30)}', 22);
  say(0, 'Um, sure. ${_words(40)}', 28 * s1Share * 2);
  say(2, 'I think hiring is the bigger risk. ${_words(35)}', 18);
  say(0, 'Right, you know, ${_words(30)}', 20);

  final names = me ? {'Speaker 1': 'John', 'Speaker 2': 'Priya', 'Speaker 3': 'Raj'} : {'Speaker 1': 'John', 'Speaker 2': 'Priya'};
  return MeetingSession(
    id: id,
    title: title,
    aiSummary: digest.summary,
    startTime: start,
    endTime: start.add(const Duration(minutes: 32)),
    entries: entries,
    speakerNames: names,
    meSpeakerKey: me ? 'Speaker 1' : null,
    coachingReport: CoachingReport(metrics: ParticipationAnalyzer.analyze(entries), generatedAt: start),
    digest: digest,
    feedback: me
        ? CoachingFeedback(
            strengths: const [
              FeedbackItem('You framed the decision clearly', evidence: 'we should lock the budget this week'),
              FeedbackItem('You kept a steady pace', evidence: null),
            ],
            improvements: const [
              FeedbackItem('Leave room after a question',
                  evidence: 'Can we check the forecast first',
                  tip: 'Pause for two seconds after asking, before adding context.'),
              FeedbackItem('Trim filler words', tip: 'Replace "you know" with a short silence.'),
            ],
            goalNotes: const ['Interruptions goal met: 0 this meeting.'],
            generatedAt: start,
          )
        : null,
  );
}

List<MeetingSession> sampleSessions() => [
      _meeting(
        'm4',
        DateTime(2026, 10, 19, 10),
        'Q3 budget review',
        me: true,
        digest: MeetingDigest(
          summary:
              'John opened the review by asking whether the Q3 budget could absorb the two engineering hires Raj proposed. '
              'Priya walked through the latest forecast, which shows a 12% shortfall if hiring starts in October. '
              'Raj argued the roles were blocking the launch; John and Priya preferred to wait for the final forecast. '
              'They agreed to hold hiring until the forecast is final, then turned to pricing and set a review for next Monday. '
              'The overrun approval path was left open.',
          topics: const [
            DigestTopic('Q3 budget', raisedBy: 'John', summary: 'Forecast shows a 12% shortfall if hiring starts in October. Priya will send the updated numbers; John wants the decision tied to them.'),
            DigestTopic('Hiring', raisedBy: 'Raj', summary: 'Raj wants two engineers now because the launch is blocked on them. Agreed to hold until the forecast is final, then revisit.'),
            DigestTopic('Pricing', summary: 'Starter and Team tiers to be reviewed next Monday; John drafts the options.'),
          ],
          risks: const ['Launch may slip if hiring waits for the final forecast', 'No agreed owner for approving a budget overrun'],
          keyFacts: const ['Forecast shortfall: 12% if hiring starts in October', 'Two engineering roles requested', 'Pricing review: next Monday'],
          decisions: const [DigestDecision('Hold hiring until the Q3 forecast is final', rationale: 'The forecast shows a 12% shortfall if hiring starts in October.', evidence: 'we hold off until the forecast is final'), DigestDecision('Review pricing tiers next Monday')],
          actionItems: const [DigestAction('Send the updated forecast', owner: 'Priya'), DigestAction('Draft pricing options', owner: 'John', due: 'before Monday')],
          openQuestions: const [DigestQuestion('Who approves the budget overrun?', asker: 'Raj', context: 'Came up when the shortfall was shown; no one owned it.')],
          generatedAt: DateTime(2026, 10, 19),
        ),
      ),
      _meeting(
        'm3',
        DateTime(2026, 10, 12, 14),
        'Launch planning',
        s1Share: 0.7,
        digest: MeetingDigest(
          summary: 'Launch date moved to November; marketing needs the pricing page first.',
          topics: const [DigestTopic('Launch', raisedBy: 'Priya'), DigestTopic('Pricing'), DigestTopic('Roadmap')],
          decisions: const [DigestDecision('Launch moves to the first week of November')],
          actionItems: const [DigestAction('Publish the pricing page', owner: 'John'), DigestAction('Brief the support team', owner: 'Raj')],
          openQuestions: const [DigestQuestion('Do we need legal review for the new tiers?', asker: 'Priya')],
          generatedAt: DateTime(2026, 10, 12),
        ),
      ),
      _meeting(
        'm2',
        DateTime(2026, 10, 5, 9, 30),
        'Hiring sync',
        s1Share: 0.6,
        digest: MeetingDigest(
          summary: 'Two engineering roles approved, subject to the Q3 budget.',
          topics: const [DigestTopic('Hiring', raisedBy: 'Raj'), DigestTopic('Q3 budget'), DigestTopic('Onboarding')],
          decisions: const [DigestDecision('Open two engineering roles')],
          actionItems: const [DigestAction('Post the job descriptions', owner: 'Raj')],
          openQuestions: const [],
          generatedAt: DateTime(2026, 10, 5),
        ),
      ),
      _meeting(
        'm1',
        DateTime(2026, 9, 28, 16),
        'Roadmap workshop',
        s1Share: 0.5,
        digest: MeetingDigest(
          summary: 'Prioritised the roadmap for Q4; onboarding flow is the main bet.',
          topics: const [DigestTopic('Roadmap', raisedBy: 'Priya'), DigestTopic('Onboarding'), DigestTopic('Launch')],
          decisions: const [DigestDecision('Onboarding redesign is the top Q4 priority')],
          actionItems: const [DigestAction('Write the onboarding brief', owner: 'Priya')],
          openQuestions: const [DigestQuestion('How do we measure activation?', asker: 'John')],
          generatedAt: DateTime(2026, 9, 28),
        ),
      ),
    ];

/// [old] mimics meetings saved before diarisation/coaching: one placeholder
/// speaker, no timings, no report, no notes, no names.
String sampleHistoryJson({bool old = false}) {
  final list = sampleSessions().map((s) => s.toJson()).toList();
  if (!old) return jsonEncode(list);
  for (final m in list) {
    m
      ..remove('coachingReport')
      ..remove('digest')
      ..remove('feedback')
      ..remove('meSpeakerKey')
      ..['speakerNames'] = <String, dynamic>{};
    for (final e in (m['entries'] as List).cast<Map<String, dynamic>>()) {
      e
        ..['speaker'] = 'Meeting Participant'
        ..remove('speakerIndex')
        ..remove('startSec')
        ..remove('endSec');
    }
  }
  return jsonEncode(list);
}

Map<String, Object> samplePrefs({bool old = false}) => {
      AppConstants.prefMeetingHistory: sampleHistoryJson(old: old),
      AppConstants.prefMyName: 'John',
      AppConstants.prefGoals: jsonEncode([
        const Goal(GoalType.interruptions, 1).toJson(),
        const Goal(GoalType.fillers, 3).toJson(),
        const Goal(GoalType.questions, 3).toJson(),
      ]),
      AppConstants.prefDeepgramApiKey: 'preview',
      AppConstants.prefGeminiApiKey: 'preview',
    };

UploadedDocument sampleDocument() {
  GraphNode n(String id, String name, String type, Set<int> chunks) =>
      GraphNode(id: id, name: name, type: type, chunkIndexes: chunks);
  final chunks = [
    'Pricing tiers: Starter, Team and Enterprise. Enterprise includes SSO and audit logs.',
    'The Q3 forecast assumes 12% growth driven by the Team tier.',
    'Support is staffed 9 to 6 with an on-call engineer for Enterprise customers.',
    'Legal review is required before publishing new pricing tiers.',
  ];
  return UploadedDocument(
    id: 'doc1',
    fileName: 'pricing-and-forecast.pdf',
    fileType: 'pdf',
    fullText: chunks.join(' '),
    chunks: [for (final c in chunks) DocumentChunk(text: c, keywords: TextSimilarity.tokenize(c))],
    keywords: TextSimilarity.tokenize(chunks.join(' ')),
    summary: 'Pricing tiers, the Q3 growth forecast and support coverage.',
    charCount: 400,
    status: DocStatus.ready,
    uploadedAt: DateTime(2026, 10, 18),
    graphStatus: GraphStatus.ready,
    graph: DocGraph(
      nodes: [
        n('pricing', 'Pricing', 'concept', {0, 3}),
        n('starter', 'Starter', 'product', {0}),
        n('team', 'Team', 'product', {0, 1}),
        n('enterprise', 'Enterprise', 'product', {0, 2}),
        n('sso', 'SSO', 'concept', {0}),
        n('forecast', 'Q3 budget', 'metric', {1}),
        n('growth', '12% growth', 'metric', {1}),
        n('support', 'Support', 'org', {2}),
        n('oncall', 'Raj', 'person', {2}),
        n('legal', 'Legal review', 'org', {3}),
      ],
      edges: const [
        GraphEdge(from: 'pricing', to: 'starter', relation: 'includes', chunkIndex: 0),
        GraphEdge(from: 'pricing', to: 'team', relation: 'includes', chunkIndex: 0),
        GraphEdge(from: 'pricing', to: 'enterprise', relation: 'includes', chunkIndex: 0),
        GraphEdge(from: 'enterprise', to: 'sso', relation: 'includes', chunkIndex: 0),
        GraphEdge(from: 'forecast', to: 'growth', relation: 'assumes', chunkIndex: 1),
        GraphEdge(from: 'team', to: 'forecast', relation: 'drives', chunkIndex: 1),
        GraphEdge(from: 'support', to: 'oncall', relation: 'staffed by', chunkIndex: 2),
        GraphEdge(from: 'support', to: 'enterprise', relation: 'covers', chunkIndex: 2),
        GraphEdge(from: 'legal', to: 'pricing', relation: 'must approve', chunkIndex: 3),
      ],
    ),
  );
}
