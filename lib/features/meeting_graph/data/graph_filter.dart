import '../../documents/domain/models/doc_graph.dart';

/// Keeps a large graph readable: only chosen node types (or [groupOf] groups), and at most
/// [limit] nodes, preferring the best-connected ones.
class GraphFilter {
  static DocGraph apply(
    DocGraph graph, {
    required Set<String> types,
    int? limit,
    String Function(GraphNode node)? groupOf,
  }) {
    final candidates = graph.nodes.where((n) => types.contains(groupOf?.call(n) ?? n.type)).toList();

    final degree = <String, int>{};
    for (final e in graph.edges) {
      degree[e.from] = (degree[e.from] ?? 0) + 1;
      degree[e.to] = (degree[e.to] ?? 0) + 1;
    }
    candidates.sort((a, b) => (degree[b.id] ?? 0).compareTo(degree[a.id] ?? 0));
    final kept = (limit == null ? candidates : candidates.take(limit)).toList();
    final ids = {for (final n in kept) n.id};

    return DocGraph(
      nodes: kept,
      edges: [for (final e in graph.edges) if (ids.contains(e.from) && ids.contains(e.to)) e],
    );
  }
}
