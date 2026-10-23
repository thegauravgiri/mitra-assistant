import '../../../core/utils/name_canonicalizer.dart';
import '../../documents/domain/models/doc_graph.dart';
import '../../documents/domain/models/uploaded_document.dart';
import '../../history/domain/models/meeting_session.dart';
import 'meeting_graph_builder.dart';

/// One graph for meetings AND documents.
///
/// Meetings come from [MeetingGraphBuilder]. Each ready document adds a
/// document node linked ("mentions") to its most important entities. A
/// document entity is linked ("same as") to a meeting topic or person only when
/// the names match, so the graph never claims a connection that isn't there.
/// Entities are linked, not merged: retrieval keeps using each document's own
/// graph, this one is for seeing how everything relates.
class CombinedGraphBuilder {
  static const int maxEntitiesPerDocument = 25;
  static const String bridgeRelation = 'same as';

  static DocGraph build(List<MeetingSession> sessions, List<UploadedDocument> documents) {
    final meetings = MeetingGraphBuilder.build(sessions);
    final nodes = {for (final n in meetings.nodes) n.id: n};
    final edges = [...meetings.edges];

    // topics and people already in the graph: the only things documents may link to
    final names = NameCanonicalizer();
    final bridgeTargets = <String, String>{};
    for (final n in meetings.nodes) {
      if (n.type != 'topic' && n.type != 'person') continue;
      final key = names.canonical(n.name);
      if (key.isNotEmpty) bridgeTargets.putIfAbsent(key, () => n.id);
    }

    String truncate(String t, int n) => t.length > n ? '${t.substring(0, n - 1)}…' : t;

    for (final doc in documents) {
      if (doc.status != DocStatus.ready) continue;
      final docId = 'doc:${doc.id}';
      nodes[docId] = GraphNode(
        id: docId,
        name: truncate(doc.fileName, 36),
        type: 'document',
        sourceIds: {doc.id},
        detail: doc.summary,
      );

      final g = doc.graph;
      if (doc.graphStatus != GraphStatus.ready || g == null) continue;

      final degree = <String, int>{};
      for (final e in g.edges) {
        degree[e.from] = (degree[e.from] ?? 0) + 1;
        degree[e.to] = (degree[e.to] ?? 0) + 1;
      }
      final ranked = [...g.nodes]..sort((a, b) {
          final sa = (degree[a.id] ?? 0) * 2 + a.chunkIndexes.length;
          final sb = (degree[b.id] ?? 0) * 2 + b.chunkIndexes.length;
          return sb.compareTo(sa);
        });
      final kept = ranked.take(maxEntitiesPerDocument).toList();
      final keptIds = {for (final n in kept) n.id};
      String entityId(String id) => 'de:${doc.id}:$id';

      for (final e in kept) {
        final id = entityId(e.id);
        nodes[id] = GraphNode(
          id: id,
          name: e.name,
          type: e.type,
          chunkIndexes: e.chunkIndexes,
          sourceIds: {doc.id},
        );
        edges.add(GraphEdge(from: docId, to: id, relation: 'mentions', chunkIndex: 0));

        final key = names.find(e.name);
        final target = key == null ? null : bridgeTargets[key];
        if (target != null) {
          edges.add(GraphEdge(from: id, to: target, relation: bridgeRelation, chunkIndex: 0));
        }
      }
      for (final e in g.edges) {
        if (keptIds.contains(e.from) && keptIds.contains(e.to)) {
          edges.add(GraphEdge(from: entityId(e.from), to: entityId(e.to), relation: e.relation, chunkIndex: e.chunkIndex));
        }
      }
    }

    return DocGraph(nodes: nodes.values.toList(), edges: edges);
  }
}
