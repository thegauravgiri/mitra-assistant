import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:mitra_assistant/core/utils/text_similarity.dart';
import 'package:mitra_assistant/features/documents/data/document_repository.dart';
import 'package:mitra_assistant/features/documents/domain/models/doc_graph.dart';
import 'package:mitra_assistant/features/documents/domain/models/uploaded_document.dart';

UploadedDocument doc(String id, {DocStatus status = DocStatus.ready, GraphStatus graphStatus = GraphStatus.ready, bool graph = true}) {
  const text = 'Pricing tiers include Starter and Team. Legal must approve pricing.';
  return UploadedDocument(
    id: id,
    fileName: '$id.pdf',
    fileType: 'pdf',
    fullText: text,
    chunks: [DocumentChunk(text: text, keywords: TextSimilarity.tokenize(text))],
    keywords: TextSimilarity.tokenize(text),
    summary: 'About pricing.',
    charCount: text.length,
    status: status,
    isPinned: true,
    uploadedAt: DateTime(2026, 10, 18),
    graphStatus: graphStatus,
    graph: graph
        ? DocGraph(
            nodes: const [
              GraphNode(id: 'pricing', name: 'Pricing tiers', type: 'concept', chunkIndexes: {0}),
              GraphNode(id: 'legal', name: 'Legal', type: 'org', chunkIndexes: {0}),
            ],
            edges: const [GraphEdge(from: 'legal', to: 'pricing', relation: 'must approve', chunkIndex: 0)],
          )
        : null,
  );
}

void main() {
  test('document JSON round-trips including chunks, keywords and the graph', () {
    final back = UploadedDocument.fromJson(doc('a').toJson());
    expect(back.fileName, 'a.pdf');
    expect(back.isPinned, isTrue);
    expect(back.chunks.single.keywords, contains('pricing'));
    expect(back.keywords, contains('legal'));
    expect(back.graphStatus, GraphStatus.ready);
    expect(back.graph!.edges.single.relation, 'must approve');
    expect(back.graph!.node('legal')!.chunkIndexes, {0});
  });

  test('an interrupted graph build is not restored as "building"', () {
    final back = UploadedDocument.fromJson(doc('a', graphStatus: GraphStatus.building, graph: false).toJson());
    expect(back.graphStatus, GraphStatus.none);
    final noGraph = UploadedDocument.fromJson(doc('b', graphStatus: GraphStatus.ready, graph: false).toJson());
    expect(noGraph.graphStatus, GraphStatus.none);
  });

  test('repository saves finished documents and loads them back', () async {
    final dir = await Directory.systemTemp.createTemp('mitra_docs_test');
    addTearDown(() => dir.delete(recursive: true));
    final repo = DocumentRepository(directory: () async => dir);

    expect(await repo.load(), isEmpty); // nothing saved yet
    await repo.save([doc('a'), doc('b'), doc('parsing', status: DocStatus.parsing)]);

    final loaded = await DocumentRepository(directory: () async => dir).load();
    expect(loaded.map((d) => d.id), ['a', 'b']); // the unfinished one is skipped
    expect(loaded.first.graph!.nodes.length, 2);
  });

  test('a corrupt file loads as empty instead of crashing', () async {
    final dir = await Directory.systemTemp.createTemp('mitra_docs_test');
    addTearDown(() => dir.delete(recursive: true));
    await File('${dir.path}/documents.json').writeAsString('{not json');
    expect(await DocumentRepository(directory: () async => dir).load(), isEmpty);
  });
}
