import 'package:flutter_test/flutter_test.dart';
import 'package:mitra_assistant/core/utils/name_canonicalizer.dart';
import 'package:mitra_assistant/core/utils/text_similarity.dart';
import 'package:mitra_assistant/features/coaching/domain/models/meeting_digest.dart';
import 'package:mitra_assistant/features/documents/domain/models/doc_graph.dart';
import 'package:mitra_assistant/features/documents/domain/models/uploaded_document.dart';
import 'package:mitra_assistant/features/history/domain/models/meeting_session.dart';
import 'package:mitra_assistant/features/meeting_graph/data/combined_graph_builder.dart';
import 'package:mitra_assistant/features/meeting_graph/data/graph_filter.dart';
import 'package:mitra_assistant/features/transcription/domain/models/transcript_entry.dart';

MeetingSession meeting() => MeetingSession(
      id: 'm1',
      title: 'Pricing review',
      aiSummary: '',
      startTime: DateTime(2026, 10, 12),
      endTime: DateTime(2026, 10, 12, 0, 30),
      entries: [TranscriptEntry(id: 'e', text: 'hi', timestamp: DateTime(2026), isFinal: true)],
      speakerNames: const {'Speaker 1': 'Raj'},
      digest: MeetingDigest(topics: const [DigestTopic('Pricing tiers'), DigestTopic('Hiring')], generatedAt: DateTime(2026)),
    );

UploadedDocument doc({DocStatus status = DocStatus.ready, DocGraph? graph, int extra = 0}) {
  final nodes = [
    const GraphNode(id: 'p', name: 'pricing tiers', type: 'concept', chunkIndexes: {0}),
    const GraphNode(id: 'r', name: 'Raj', type: 'person', chunkIndexes: {1}),
    const GraphNode(id: 'x', name: 'Enterprise plan', type: 'product', chunkIndexes: {0}),
    for (var i = 0; i < extra; i++) GraphNode(id: 'extra$i', name: 'Extra $i', chunkIndexes: {i}),
  ];
  return UploadedDocument(
    id: 'd1',
    fileName: 'pricing.pdf',
    fileType: 'pdf',
    fullText: 't',
    chunks: [DocumentChunk(text: 't', keywords: TextSimilarity.tokenize('t'))],
    keywords: const {},
    summary: 'Pricing overview',
    charCount: 1,
    status: status,
    uploadedAt: DateTime(2026),
    graphStatus: GraphStatus.ready,
    graph: graph ??
        DocGraph(
          nodes: nodes,
          edges: const [GraphEdge(from: 'p', to: 'x', relation: 'includes', chunkIndex: 0)],
        ),
  );
}

void main() {
  group('CombinedGraphBuilder', () {
    final g = CombinedGraphBuilder.build([meeting()], [doc()]);
    bool edge(String f, String rel, String t) => g.edges.any((e) => e.from == f && e.relation == rel && e.to == t);

    test('keeps the meeting graph and adds a document node with its entities', () {
      expect(g.node('m:m1'), isNotNull);
      expect(g.node('doc:d1')!.type, 'document');
      expect(g.node('doc:d1')!.detail, 'Pricing overview');
      expect(g.node('de:d1:x')!.name, 'Enterprise plan');
      expect(edge('doc:d1', 'mentions', 'de:d1:x'), isTrue);
      expect(edge('de:d1:p', 'includes', 'de:d1:x'), isTrue); // document relations preserved
    });

    test('links a document entity to a meeting topic / person only when names match', () {
      expect(edge('de:d1:p', CombinedGraphBuilder.bridgeRelation, 't:pricing tiers'), isTrue); // case-insensitive
      expect(edge('de:d1:r', CombinedGraphBuilder.bridgeRelation, 'p:raj'), isTrue);
      expect(g.edges.where((e) => e.relation == CombinedGraphBuilder.bridgeRelation).length, 2);
      // "Enterprise plan" matches nothing, so it is NOT linked to any meeting node
      expect(g.edges.any((e) => e.from == 'de:d1:x' && e.relation == CombinedGraphBuilder.bridgeRelation), isFalse);
    });

    test('entities are linked, not merged: the topic node stays separate', () {
      expect(g.node('t:pricing tiers'), isNotNull);
      expect(g.node('de:d1:p'), isNotNull);
    });

    test('documents that are not ready, or have no graph, add little or nothing', () {
      expect(CombinedGraphBuilder.build([meeting()], [doc(status: DocStatus.parsing)]).node('doc:d1'), isNull);
      final noGraph = doc().copyWith(graphStatus: GraphStatus.failed);
      final built = CombinedGraphBuilder.build([meeting()], [noGraph]);
      expect(built.node('doc:d1'), isNotNull); // the file itself still shows
      expect(built.nodes.where((n) => n.id.startsWith('de:')), isEmpty);
    });

    test('caps entities per document, keeping the best connected', () {
      final big = CombinedGraphBuilder.build([], [doc(extra: 60)]);
      expect(big.nodes.where((n) => n.id.startsWith('de:')).length, CombinedGraphBuilder.maxEntitiesPerDocument);
      expect(big.node('de:d1:p'), isNotNull); // linked entity survives the cap
    });

    test('works with no meetings and with no documents', () {
      expect(CombinedGraphBuilder.build([], []).isEmpty, isTrue);
      expect(CombinedGraphBuilder.build([meeting()], []).nodes.any((n) => n.type == 'document'), isFalse);
    });
  });

  test('NameCanonicalizer.find does not register new names', () {
    final c = NameCanonicalizer();
    c.canonical('Pricing tiers');
    expect(c.find('pricing TIERS'), isNotNull);
    expect(c.find('Something else'), isNull);
    expect(c.find('Something else'), isNull); // still not registered
  });

  test('GraphFilter can filter by group instead of node type', () {
    final g = CombinedGraphBuilder.build([meeting()], [doc()]);
    String group(GraphNode n) => n.type == 'document' ? 'document' : (n.id.startsWith('de:') ? 'entity' : n.type);
    final onlyDocs = GraphFilter.apply(g, types: {'document'}, groupOf: group);
    expect(onlyDocs.nodes.map((n) => n.id), ['doc:d1']);
    final entities = GraphFilter.apply(g, types: {'entity'}, groupOf: group);
    expect(entities.nodes.every((n) => n.id.startsWith('de:')), isTrue);
  });
}
