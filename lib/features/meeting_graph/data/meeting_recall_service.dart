import 'package:intl/intl.dart';
import '../../../core/utils/text_similarity.dart';
import '../../documents/domain/models/doc_graph.dart';

/// Looks up what earlier meetings recorded about the topics being discussed
/// right now. Pure lookups over the meeting graph, so it adds no delay.
class MeetingRecallService {
  /// Returns a short text block (empty when nothing relevant). Seeds are
  /// topic nodes whose name appears in [transcriptWindow]; for each, the most
  /// recent meetings that discussed it and the decisions / actions / open
  /// questions tied to it.
  static String recall(
    String transcriptWindow,
    DocGraph graph, {
    int maxChars = 900,
    int maxTopics = 2,
    int meetingsPerTopic = 2,
  }) {
    if (graph.isEmpty) return '';
    final tokens = TextSimilarity.tokenize(transcriptWindow);
    if (tokens.isEmpty) return '';

    final seeds = graph
        .seedNodes(tokens)
        .map(graph.node)
        .whereType<GraphNode>()
        .where((n) => n.type == 'topic')
        .toList()
      ..sort((a, b) {
        final ha = tokens.intersection(TextSimilarity.tokenize(a.name)).length;
        final hb = tokens.intersection(TextSimilarity.tokenize(b.name)).length;
        return hb.compareTo(ha);
      });
    if (seeds.isEmpty) return '';

    // items about a topic: edge item -about-> topic
    final itemsByTopic = <String, List<GraphNode>>{};
    for (final e in graph.edges) {
      if (e.relation != 'about') continue;
      final item = graph.node(e.from);
      if (item != null) (itemsByTopic[e.to] ??= []).add(item);
    }
    final dateFmt = DateFormat('d MMM yyyy');
    // what each meeting said about each topic
    final said = <String, String>{
      for (final e in graph.edges)
        if (e.relation == 'discussed' && e.detail != null) '${e.from}|${e.to}': e.detail!,
    };

    final out = StringBuffer();
    for (final topic in seeds.take(maxTopics)) {
      final meetings = topic.sourceIds
          .map((id) => graph.node('m:$id'))
          .whereType<GraphNode>()
          .toList()
        ..sort((a, b) => (b.date ?? DateTime(0)).compareTo(a.date ?? DateTime(0)));

      for (final m in meetings.take(meetingsPerTopic)) {
        final sid = m.id.substring(2);
        final when = m.date == null ? '' : dateFmt.format(m.date!);
        final lines = StringBuffer('- "${topic.name}" came up on $when ("${m.name}")');
        final summary = said['${m.id}|${topic.id}'];
        if (summary != null) {
          lines.write(': ${summary.length > 260 ? '${summary.substring(0, 259)}…' : summary}');
        }
        for (final item in itemsByTopic[topic.id] ?? const <GraphNode>[]) {
          if (!item.sourceIds.contains(sid)) continue;
          final label = item.type == 'decision'
              ? 'decided'
              : item.type == 'action'
                  ? 'action'
                  : 'left unanswered';
          lines.write('; $label: ${item.detail ?? item.name}');
        }
        lines.writeln();
        if (out.length + lines.length > maxChars) return out.toString().trim();
        out.write(lines);
      }
    }
    return out.toString().trim();
  }
}
