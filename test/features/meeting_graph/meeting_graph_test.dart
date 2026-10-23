import 'package:flutter_test/flutter_test.dart';
import 'package:mitra_assistant/features/coaching/domain/models/meeting_digest.dart';
import 'package:mitra_assistant/features/documents/domain/models/doc_graph.dart';
import 'package:mitra_assistant/features/history/domain/models/meeting_session.dart';
import 'package:mitra_assistant/features/meeting_graph/data/meeting_graph_builder.dart';
import 'package:mitra_assistant/features/meeting_graph/data/meeting_recall_service.dart';
import 'package:mitra_assistant/features/transcription/domain/models/transcript_entry.dart';

TranscriptEntry entry() => TranscriptEntry(id: 'e', text: 'hi', timestamp: DateTime(2026), isFinal: true);

MeetingSession meeting(
  String id,
  DateTime start, {
  Map<String, String> names = const {},
  MeetingDigest? digest,
  String title = 'Meeting',
}) =>
    MeetingSession(
      id: id,
      title: title,
      aiSummary: '',
      startTime: start,
      endTime: start.add(const Duration(minutes: 30)),
      entries: [entry()],
      speakerNames: names,
      digest: digest,
    );

final oct12 = meeting(
  'a',
  DateTime(2026, 10, 12),
  title: 'Budget sync',
  names: {'Speaker 1': 'Sneha', 'Speaker 2': 'Raj'},
  digest: MeetingDigest(
    topics: const [DigestTopic('Q3 budget', raisedBy: 'Raj', summary: 'Forecast shows a 12% shortfall; Raj wants two hires anyway.'), DigestTopic('Hiring')],
    decisions: const [DigestDecision('Freeze Q3 budget until the forecast lands')],
    actionItems: const [DigestAction('Send the budget forecast', owner: 'Raj')],
    openQuestions: const [DigestQuestion('Who approves the budget overrun?', asker: 'Sneha')],
    generatedAt: DateTime(2026),
  ),
);

final oct19 = meeting(
  'b',
  DateTime(2026, 10, 19),
  title: 'Planning',
  names: {'Speaker 1': 'sneha'}, // different label, different casing
  digest: MeetingDigest(
    topics: const [DigestTopic('q3 budget'), DigestTopic('Roadmap')],
    generatedAt: DateTime(2026),
  ),
);

void main() {
  group('MeetingGraphBuilder', () {
    final g = MeetingGraphBuilder.build([oct19, oct12]); // order must not matter

    GraphNode node(String id) => g.node(id)!;
    bool edge(String from, String rel, String to) =>
        g.edges.any((e) => e.from == from && e.relation == rel && e.to == to);

    test('the same topic across meetings is one node linked to both', () {
      final topics = g.nodes.where((n) => n.type == 'topic').toList();
      expect(topics.where((n) => n.name.toLowerCase() == 'q3 budget').length, 1);
      final t = node('t:q3 budget');
      expect(t.sourceIds, {'a', 'b'});
      expect(edge('m:a', 'discussed', 't:q3 budget'), isTrue);
      expect(edge('m:b', 'discussed', 't:q3 budget'), isTrue);
    });

    test('a person named differently-cased in two meetings is one node', () {
      expect(g.nodes.where((n) => n.type == 'person' && n.name.toLowerCase() == 'sneha').length, 1);
      expect(node('p:sneha').sourceIds, {'a', 'b'});
      expect(edge('p:sneha', 'attended', 'm:a'), isTrue);
      expect(edge('p:sneha', 'attended', 'm:b'), isTrue);
    });

    test('owners, askers and raisers are linked; items attach to their topic', () {
      expect(edge('p:raj', 'owns', 'a:a:0'), isTrue);
      expect(edge('p:sneha', 'asked', 'q:a:0'), isTrue);
      expect(edge('p:raj', 'raised', 't:q3 budget'), isTrue);
      expect(edge('d:a:0', 'about', 't:q3 budget'), isTrue);
      expect(edge('a:a:0', 'about', 't:q3 budget'), isTrue);
      expect(edge('d:a:0', 'about', 't:hiring'), isFalse);
    });

    test('unnamed speakers never become person nodes; empty sessions are skipped', () {
      final built = MeetingGraphBuilder.build([
        meeting('x', DateTime(2026), names: {}, digest: MeetingDigest(
          actionItems: const [DigestAction('Do it', owner: 'Speaker 2')],
          generatedAt: DateTime(2026),
        )),
        MeetingSession(
          id: 'empty',
          title: 'e',
          aiSummary: '',
          startTime: DateTime(2026),
          endTime: DateTime(2026),
          entries: const [],
        ),
      ]);
      expect(built.nodes.where((n) => n.type == 'person'), isEmpty);
      expect(built.node('m:empty'), isNull);
      expect(built.node('a:x:0'), isNotNull);
    });
  });

  group('MeetingRecallService', () {
    final g = MeetingGraphBuilder.build([oct12, oct19]);

    test('recalls decisions, actions and unanswered questions on a topic hit', () {
      final r = MeetingRecallService.recall('So where are we on the budget this quarter?', g);
      expect(r, contains('"Q3 budget" came up on 12 Oct 2026'));
      expect(r, contains('decided: Freeze Q3 budget'));
      expect(r, contains('action: Raj: Send the budget forecast'));
      expect(r, contains('left unanswered: Sneha asked: Who approves the budget overrun?'));
      expect(r, contains('19 Oct 2026')); // the later meeting also discussed it
    });

    test('recall includes what that meeting actually said about the topic', () {
      final r = MeetingRecallService.recall('So where are we on the budget this quarter?', g);
      expect(r, contains('Forecast shows a 12% shortfall; Raj wants two hires anyway.'));
    });

    test('the per-meeting topic summary lives on the "discussed" link and survives JSON', () {
      final e = g.edges.firstWhere((e) => e.relation == 'discussed' && e.detail != null);
      expect(e.detail, contains('12% shortfall'));
      expect(GraphEdge.fromJson(e.toJson()).detail, e.detail);
    });

    test('returns nothing without a topic hit, on empty graph, or for person names only', () {
      expect(MeetingRecallService.recall('Let us talk about lunch', g), isEmpty);
      expect(MeetingRecallService.recall('Raj and Sneha are here', g), isEmpty);
      expect(MeetingRecallService.recall('budget', DocGraph.empty()), isEmpty);
      expect(MeetingRecallService.recall('', g), isEmpty);
    });

    test('respects the character cap', () {
      final r = MeetingRecallService.recall('budget', g, maxChars: 120);
      expect(r.length, lessThanOrEqualTo(120));
    });
  });
}
