import 'package:flutter_test/flutter_test.dart';
import 'package:mitra_assistant/features/documents/domain/models/doc_graph.dart';
import 'package:mitra_assistant/features/meeting_graph/data/graph_filter.dart';

void main() {
  GraphNode n(String id, String type) => GraphNode(id: id, name: id, type: type);
  GraphEdge e(String a, String b) => GraphEdge(from: a, to: b, relation: 'r', chunkIndex: 0);

  final g = DocGraph(
    nodes: [n('hub', 'topic'), n('a', 'person'), n('b', 'person'), n('c', 'action'), n('lonely', 'topic')],
    edges: [e('hub', 'a'), e('hub', 'b'), e('hub', 'c'), e('a', 'c')],
  );

  test('filters by type and drops edges to hidden nodes', () {
    final f = GraphFilter.apply(g, types: {'topic', 'person'});
    expect(f.nodes.map((x) => x.id).toSet(), {'hub', 'a', 'b', 'lonely'});
    expect(f.edges.length, 2); // hub-a, hub-b; hub-c and a-c dropped
  });

  test('limit keeps the best-connected nodes first', () {
    final f = GraphFilter.apply(g, types: {'topic', 'person', 'action'}, limit: 2);
    expect(f.nodes.map((x) => x.id).toSet(), {'hub', 'a'});
    expect(f.edges.length, 1);
  });

  test('no limit keeps everything of the chosen types', () {
    expect(GraphFilter.apply(g, types: {'topic', 'person', 'action'}).nodes.length, 5);
  });
}
