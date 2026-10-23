import 'package:flutter_test/flutter_test.dart';
import 'package:mitra_assistant/core/utils/text_similarity.dart';
import 'package:mitra_assistant/features/documents/data/document_relevance_service.dart';
import 'package:mitra_assistant/features/documents/data/graph_extractor_service.dart';
import 'package:mitra_assistant/features/documents/domain/models/doc_graph.dart';
import 'package:mitra_assistant/features/documents/domain/models/uploaded_document.dart';

DocumentChunk chunk(String text) =>
    DocumentChunk(text: text, keywords: TextSimilarity.tokenize(text));

final chunks = [
  chunk('The quarterly forecast was shared with the finance board in September.'),
  chunk('Total allocation for engineering hires is capped at two million dollars.'),
  chunk('The office relocation is planned for next spring.'),
];

// "forecast" (chunk 0) is linked to "allocation" (chunk 1); chunk 2 is unrelated.
DocGraph buildGraph() => DocGraph(
      nodes: const [
        GraphNode(id: 'forecast', name: 'forecast', type: 'concept', chunkIndexes: {0}),
        GraphNode(id: 'allocation', name: 'allocation', type: 'concept', chunkIndexes: {1}),
        GraphNode(id: 'relocation', name: 'office relocation', type: 'concept', chunkIndexes: {2}),
      ],
      edges: const [
        GraphEdge(from: 'forecast', to: 'allocation', relation: 'drives', chunkIndex: 0),
      ],
    );

UploadedDocument doc({DocGraph? graph, GraphStatus status = GraphStatus.none}) =>
    UploadedDocument(
      id: 'd',
      fileName: 'plan.txt',
      fileType: 'txt',
      fullText: chunks.map((c) => c.text).join(' '),
      chunks: chunks,
      // Deliberately tiny so the keyword gate alone would not admit the document.
      keywords: TextSimilarity.tokenize('a b c d e f g h i j k l m n o p'),
      charCount: 100,
      status: DocStatus.ready,
      uploadedAt: DateTime(2026),
      graph: graph,
      graphStatus: status,
    );

void main() {
  group('DocGraph', () {
    final g = buildGraph();

    test('seed nodes need at least half of the name tokens', () {
      expect(g.seedNodes({'forecast'}), {'forecast'});
      expect(g.seedNodes({'office'}), {'relocation'}); // 1 of 2 tokens
      expect(g.seedNodes({'unrelated'}), isEmpty);
    });

    test('boosts the seed chunk more than the neighbour chunk', () {
      final b = g.chunkBoosts({'forecast'}, seedBoost: 0.5, neighbourBoost: 0.25);
      expect(b[0], 0.5);
      expect(b[1], 0.25);
      expect(b.containsKey(2), isFalse);
    });
  });

  group('DocumentRelevanceService with graph', () {
    final service = DocumentRelevanceService();
    const window = 'Can we revisit the forecast before the board meeting?';

    test('without a graph the document is not admitted', () {
      final r = service.getRelevantContext(transcriptWindow: window, documents: [doc()]);
      expect(r.hasContext, isFalse);
    });

    test('with a graph the connected chunk is retrieved first, though it never says "forecast"', () {
      final r = service.getRelevantContext(
        transcriptWindow: window,
        documents: [doc(graph: buildGraph(), status: GraphStatus.ready)],
        maxContextChars: 220,
      );
      expect(r.hasContext, isTrue);
      expect(r.documentContext, contains('quarterly forecast'));
      expect(r.documentContext, contains('engineering hires'));
      expect(r.documentContext, isNot(contains('relocation')));
    });

    test('a graph that is not ready is ignored', () {
      final r = service.getRelevantContext(
        transcriptWindow: window,
        documents: [doc(graph: buildGraph(), status: GraphStatus.building)],
      );
      expect(r.hasContext, isFalse);
    });
  });

  group('GraphExtractorService', () {
    test('parseResponse handles fenced and wrapped JSON, and garbage', () {
      const json = '{"chunks":[{"index":0,"entities":[{"name":"forecast","type":"concept"}],"relations":[]}]}';
      expect(GraphExtractorService.parseResponse(json).single.index, 0);
      expect(GraphExtractorService.parseResponse('```json\n$json\n```').length, 1);
      expect(GraphExtractorService.parseResponse('Sure! $json Hope it helps').length, 1);
      expect(GraphExtractorService.parseResponse('nope'), isEmpty);
      expect(GraphExtractorService.parseResponse(''), isEmpty);
    });

    test('merge drops hallucinated entities, merges near-duplicates, links relations', () {
      final graph = GraphExtractorService.merge([
        const ChunkExtraction(0, [
          ExtractedEntity('forecast', 'concept'),
          ExtractedEntity('finance board', 'org'),
          ExtractedEntity('Mars colony', 'place'), // not in chunk text
        ], [
          ExtractedRelation('forecast', 'finance board', 'shared with'),
          ExtractedRelation('forecast', 'Mars colony', 'bound for'), // endpoint dropped
        ]),
        const ChunkExtraction(1, [
          ExtractedEntity('Engineering Hires', 'concept'),
          ExtractedEntity('engineering hires', 'concept'), // duplicate by name
        ], []),
      ], chunks);

      final names = graph.nodes.map((n) => n.name).toSet();
      expect(names, contains('forecast'));
      expect(names, isNot(contains('Mars colony')));
      expect(graph.nodes.where((n) => n.id == 'engineering hires').length, 1);
      expect(graph.edges.length, 1);
      expect(graph.edges.single.relation, 'shared with');
    });

    test('build batches chunks, tolerates a failing batch, throws if all fail', () async {
      var calls = 0;
      final ok = await GraphExtractorService().build(
        chunks: chunks,
        batchSize: 2,
        generate: (prompt) async {
          calls++;
          if (calls == 1) throw Exception('rate limit');
          return '{"chunks":[{"index":2,"entities":[{"name":"office relocation","type":"concept"}],"relations":[]}]}';
        },
      );
      expect(calls, 2); // 3 chunks, batch size 2
      expect(ok.nodes.single.name, 'office relocation');

      expect(
        () => GraphExtractorService().build(
          chunks: chunks,
          generate: (_) async => throw Exception('down'),
        ),
        throwsException,
      );
    });
  });
}
