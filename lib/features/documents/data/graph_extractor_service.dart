import 'dart:convert';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/logger.dart';
import '../../../core/utils/name_canonicalizer.dart';
import '../../../core/utils/text_similarity.dart';
import '../../ai_engine/data/prompt_templates.dart';
import '../domain/models/doc_graph.dart';
import '../domain/models/uploaded_document.dart';

class ExtractedEntity {
  final String name;
  final String type;
  const ExtractedEntity(this.name, this.type);
}

class ExtractedRelation {
  final String from;
  final String to;
  final String relation;
  const ExtractedRelation(this.from, this.to, this.relation);
}

class ChunkExtraction {
  final int index;
  final List<ExtractedEntity> entities;
  final List<ExtractedRelation> relations;
  const ChunkExtraction(this.index, this.entities, this.relations);
}

/// Builds a [DocGraph] from document chunks. The LLM call is injected
/// (`generate`) so parsing and merging are testable without network.
class GraphExtractorService {
  /// Sends chunks in batches and merges the results. A failing batch is
  /// skipped; throws only if every batch failed, so callers can mark the
  /// graph as failed instead of "ready but empty".
  Future<DocGraph> build({
    required List<DocumentChunk> chunks,
    required Future<String> Function(String prompt) generate,
    int batchSize = AppConstants.graphChunksPerBatch,
    int maxChunks = AppConstants.graphMaxChunks,
    int maxNodes = AppConstants.graphMaxNodes,
  }) async {
    final limit = chunks.length < maxChunks ? chunks.length : maxChunks;
    final extractions = <ChunkExtraction>[];
    var failures = 0;
    var batches = 0;

    for (var start = 0; start < limit; start += batchSize) {
      batches++;
      final end = start + batchSize < limit ? start + batchSize : limit;
      final batch = [
        for (var i = start; i < end; i++) MapEntry(i, chunks[i].text),
      ];
      try {
        final raw = await generate(PromptTemplates.buildGraphExtractionPrompt(batch));
        extractions.addAll(parseResponse(raw));
      } catch (e) {
        failures++;
        AppLogger.error('Graph extraction batch failed', e);
      }
    }

    if (batches > 0 && failures == batches) {
      throw Exception('Graph extraction failed for every batch');
    }
    return merge(extractions, chunks, maxNodes: maxNodes);
  }

  /// Defensive like `GeminiService._parseInsightsJson`: strips fences and
  /// falls back to the first `{...}` block.
  static List<ChunkExtraction> parseResponse(String raw) {
    var text = raw.trim();
    if (text.isEmpty) return [];
    text = text
        .replaceAll(RegExp(r'^```(json)?\s*', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s*```$'), '');

    dynamic parsed;
    try {
      parsed = jsonDecode(text);
    } catch (_) {
      final m = RegExp(r'\{.*\}', dotAll: true).firstMatch(text);
      if (m != null) {
        try {
          parsed = jsonDecode(m.group(0)!);
        } catch (_) {}
      }
    }

    final list = parsed is Map ? parsed['chunks'] : (parsed is List ? parsed : null);
    if (list is! List) return [];

    final out = <ChunkExtraction>[];
    for (final item in list) {
      if (item is! Map) continue;
      final index = (item['index'] as num?)?.toInt();
      if (index == null) continue;
      final entities = <ExtractedEntity>[
        for (final e in (item['entities'] as List? ?? const []))
          if (e is Map && (e['name'] as String?)?.trim().isNotEmpty == true)
            ExtractedEntity(
              (e['name'] as String).trim(),
              (e['type'] as String?)?.trim().toLowerCase() ?? 'concept',
            ),
      ];
      final relations = <ExtractedRelation>[
        for (final r in (item['relations'] as List? ?? const []))
          if (r is Map &&
              (r['from'] as String?)?.trim().isNotEmpty == true &&
              (r['to'] as String?)?.trim().isNotEmpty == true)
            ExtractedRelation(
              (r['from'] as String).trim(),
              (r['to'] as String).trim(),
              (r['relation'] as String?)?.trim() ?? 'related to',
            ),
      ];
      out.add(ChunkExtraction(index, entities, relations));
    }
    return out;
  }

  /// Merges per-chunk extractions into one graph: entities must literally
  /// appear in their chunk (drops hallucinations), near-duplicate names are
  /// merged, the most-mentioned [maxNodes] are kept.
  static DocGraph merge(
    List<ChunkExtraction> extractions,
    List<DocumentChunk> chunks, {
    int maxNodes = AppConstants.graphMaxNodes,
  }) {
    final canon = NameCanonicalizer();
    final types = <String, String>{};
    final chunkSets = <String, Set<int>>{};

    String? register(String name, String type, int chunkIndex) {
      final norm = TextSimilarity.normalize(name);
      if (norm.isEmpty) return null;
      final key = canon.canonical(name);
      types.putIfAbsent(key, () => type);
      (chunkSets[key] ??= {}).add(chunkIndex);
      return key;
    }

    bool inChunk(String name, int index) {
      if (index < 0 || index >= chunks.length) return false;
      return TextSimilarity.normalize(chunks[index].text)
          .contains(TextSimilarity.normalize(name));
    }

    final edgeDrafts = <({String from, String to, String relation, int chunk})>[];
    for (final ex in extractions) {
      final local = <String, String>{}; // normalised raw name -> canonical key
      for (final e in ex.entities) {
        if (!inChunk(e.name, ex.index)) continue;
        final key = register(e.name, e.type, ex.index);
        if (key != null) local[TextSimilarity.normalize(e.name)] = key;
      }
      for (final r in ex.relations) {
        final a = local[TextSimilarity.normalize(r.from)];
        final b = local[TextSimilarity.normalize(r.to)];
        if (a == null || b == null || a == b) continue;
        edgeDrafts.add((from: a, to: b, relation: r.relation, chunk: ex.index));
      }
    }

    final ranked = chunkSets.keys.toList()
      ..sort((a, b) => chunkSets[b]!.length.compareTo(chunkSets[a]!.length));
    final kept = ranked.take(maxNodes).toSet();

    final nodes = [
      for (final k in kept)
        GraphNode(
          id: k,
          name: canon.displayName(k),
          type: types[k] ?? 'concept',
          chunkIndexes: chunkSets[k]!,
        ),
    ];
    final seenEdges = <String>{};
    final edges = <GraphEdge>[];
    for (final e in edgeDrafts) {
      if (!kept.contains(e.from) || !kept.contains(e.to)) continue;
      if (!seenEdges.add('${e.from}|${e.relation}|${e.to}')) continue;
      edges.add(GraphEdge(from: e.from, to: e.to, relation: e.relation, chunkIndex: e.chunk));
    }
    return DocGraph(nodes: nodes, edges: edges);
  }
}
