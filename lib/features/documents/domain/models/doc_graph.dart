import '../../../../core/utils/text_similarity.dart';

class GraphNode {
  final String id;
  final String name;
  final String type;

  /// Document graphs: indexes into `UploadedDocument.chunks` where this entity appears.
  final Set<int> chunkIndexes;

  /// Meeting graphs: ids of the meetings this node appears in.
  final Set<String> sourceIds;

  /// Full text for nodes whose [name] is a shortened label (decisions, actions...).
  final String? detail;

  /// Meeting nodes: when the meeting started.
  final DateTime? date;

  const GraphNode({
    required this.id,
    required this.name,
    this.type = 'concept',
    this.chunkIndexes = const {},
    this.sourceIds = const {},
    this.detail,
    this.date,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'type': type,
        if (chunkIndexes.isNotEmpty) 'chunkIndexes': chunkIndexes.toList(),
        if (sourceIds.isNotEmpty) 'sourceIds': sourceIds.toList(),
        if (detail != null) 'detail': detail,
        if (date != null) 'date': date!.toIso8601String(),
      };

  factory GraphNode.fromJson(Map<String, dynamic> j) => GraphNode(
        id: j['id'] as String? ?? '',
        name: j['name'] as String? ?? '',
        type: j['type'] as String? ?? 'concept',
        chunkIndexes: {for (final i in j['chunkIndexes'] as List? ?? const []) (i as num).toInt()},
        sourceIds: {for (final i in j['sourceIds'] as List? ?? const []) i.toString()},
        detail: j['detail'] as String?,
        date: DateTime.tryParse(j['date'] as String? ?? ''),
      );

  GraphNode withChunk(int index) => GraphNode(
        id: id,
        name: name,
        type: type,
        chunkIndexes: {...chunkIndexes, index},
        sourceIds: sourceIds,
        detail: detail,
        date: date,
      );
}

class GraphEdge {
  final String from; // node id
  final String to; // node id
  final String relation;
  final int chunkIndex;

  /// Optional text about this link, e.g. what a meeting said about a topic.
  final String? detail;

  const GraphEdge({
    required this.from,
    required this.to,
    required this.relation,
    required this.chunkIndex,
    this.detail,
  });

  Map<String, dynamic> toJson() => {
        'from': from,
        'to': to,
        'relation': relation,
        'chunkIndex': chunkIndex,
        if (detail != null) 'detail': detail,
      };

  factory GraphEdge.fromJson(Map<String, dynamic> j) => GraphEdge(
        from: j['from'] as String? ?? '',
        to: j['to'] as String? ?? '',
        relation: j['relation'] as String? ?? 'related to',
        chunkIndex: (j['chunkIndex'] as num?)?.toInt() ?? 0,
        detail: j['detail'] as String?,
      );
}

/// Entities and relations extracted from one document, with lookup indexes
/// so retrieval at meeting time is just map lookups.
class DocGraph {
  final List<GraphNode> nodes;
  final List<GraphEdge> edges;

  final Map<String, GraphNode> _byId;
  final Map<String, Set<String>> _tokenIndex = {}; // token -> node ids
  final Map<String, Set<String>> _neighbours = {}; // node id -> node ids

  DocGraph({required this.nodes, required this.edges})
      : _byId = {for (final n in nodes) n.id: n} {
    for (final n in nodes) {
      for (final t in TextSimilarity.tokenize(n.name)) {
        (_tokenIndex[t] ??= {}).add(n.id);
      }
    }
    for (final e in edges) {
      if (!_byId.containsKey(e.from) || !_byId.containsKey(e.to)) continue;
      (_neighbours[e.from] ??= {}).add(e.to);
      (_neighbours[e.to] ??= {}).add(e.from);
    }
  }

  static DocGraph empty() => DocGraph(nodes: const [], edges: const []);

  Map<String, dynamic> toJson() => {
        'nodes': nodes.map((n) => n.toJson()).toList(),
        'edges': edges.map((e) => e.toJson()).toList(),
      };

  factory DocGraph.fromJson(Map<String, dynamic> j) => DocGraph(
        nodes: [for (final n in j['nodes'] as List? ?? const []) GraphNode.fromJson(n as Map<String, dynamic>)],
        edges: [for (final e in j['edges'] as List? ?? const []) GraphEdge.fromJson(e as Map<String, dynamic>)],
      );

  bool get isEmpty => nodes.isEmpty;

  GraphNode? node(String id) => _byId[id];

  Set<String> neighboursOf(String id) => _neighbours[id] ?? const {};

  /// Nodes named in [searchTokens]: at least half of the node name's tokens
  /// must appear (so "budget" matches on one word, "q3 budget" needs one of two).
  Set<String> seedNodes(Set<String> searchTokens) {
    if (searchTokens.isEmpty || nodes.isEmpty) return {};
    final hits = <String, int>{};
    for (final t in searchTokens) {
      for (final id in _tokenIndex[t] ?? const <String>{}) {
        hits[id] = (hits[id] ?? 0) + 1;
      }
    }
    final seeds = <String>{};
    hits.forEach((id, count) {
      final total = TextSimilarity.tokenize(_byId[id]!.name).length;
      if (total > 0 && count / total >= 0.5) seeds.add(id);
    });
    return seeds;
  }

  /// Extra score per chunk index: [seedBoost] for every seed node the chunk
  /// mentions, [neighbourBoost] for every node one hop away.
  Map<int, double> chunkBoosts(
    Set<String> searchTokens, {
    required double seedBoost,
    required double neighbourBoost,
  }) {
    final seeds = seedNodes(searchTokens);
    if (seeds.isEmpty) return {};

    final neighbours = <String>{};
    for (final s in seeds) {
      neighbours.addAll(neighboursOf(s));
    }
    neighbours.removeAll(seeds);

    final boosts = <int, double>{};
    for (final id in seeds) {
      for (final c in _byId[id]!.chunkIndexes) {
        boosts[c] = (boosts[c] ?? 0) + seedBoost;
      }
    }
    for (final id in neighbours) {
      for (final c in _byId[id]!.chunkIndexes) {
        boosts[c] = (boosts[c] ?? 0) + neighbourBoost;
      }
    }
    return boosts;
  }
}

enum GraphStatus { none, building, ready, failed }
