import '../../../core/utils/name_canonicalizer.dart';
import '../../../core/utils/text_similarity.dart';
import '../../documents/domain/models/doc_graph.dart';
import '../../history/domain/models/meeting_session.dart';

/// Builds the cross-meeting knowledge graph from saved sessions. Pure: the
/// graph is always derived from stored data, so it needs no storage of its own.
///
/// Node types: meeting, person, topic, decision, action, question.
/// Topics and people with near-identical names become one node across
/// meetings, which is what connects the meetings to each other.
class MeetingGraphBuilder {
  static final RegExp _unnamedSpeaker = RegExp(r'^(speaker \d+|meeting participant)$');

  static DocGraph build(List<MeetingSession> sessions) {
    final ordered = [...sessions]..sort((a, b) => a.startTime.compareTo(b.startTime));

    final topics = NameCanonicalizer();
    final people = NameCanonicalizer();
    final nodes = <String, GraphNode>{};
    final edges = <GraphEdge>[];
    final edgeKeys = <String>{};

    void addNode(
      String id,
      String name,
      String type,
      String sourceId, {
      String? detail,
      DateTime? date,
    }) {
      final existing = nodes[id];
      nodes[id] = GraphNode(
        id: id,
        name: existing?.name ?? name,
        type: type,
        sourceIds: {...?existing?.sourceIds, sourceId},
        detail: existing?.detail ?? detail,
        date: existing?.date ?? date,
      );
    }

    void addEdge(String from, String to, String relation, String sourceId, {String? detail}) {
      if (!nodes.containsKey(from) || !nodes.containsKey(to)) return;
      if (!edgeKeys.add('$from|$relation|$to')) return;
      edges.add(GraphEdge(from: from, to: to, relation: relation, chunkIndex: 0, detail: detail));
    }

    String truncate(String t, int n) => t.length > n ? '${t.substring(0, n - 1)}…' : t;

    for (final s in ordered) {
      if (s.entries.isEmpty) continue;
      final mid = 'm:${s.id}';
      addNode(
        mid,
        truncate(s.title, 36),
        'meeting',
        s.id,
        detail: s.digest?.summary.isNotEmpty == true ? s.digest!.summary : s.aiSummary,
        date: s.startTime,
      );

      String? person(String? label) {
        if (label == null || label.trim().isEmpty) return null;
        if (_unnamedSpeaker.hasMatch(TextSimilarity.normalize(label))) return null;
        final key = people.canonical(label);
        if (key.isEmpty) return null;
        final pid = 'p:$key';
        addNode(pid, people.displayName(key), 'person', s.id);
        return pid;
      }

      for (final name in s.speakerNames.values) {
        final pid = person(name);
        if (pid != null) addEdge(pid, mid, 'attended', s.id);
      }

      final digest = s.digest;
      if (digest == null) continue;

      final meetingTopics = <(String, Set<String>)>[];
      for (final t in digest.topics) {
        final key = topics.canonical(t.name);
        if (key.isEmpty) continue;
        final tid = 't:$key';
        addNode(tid, topics.displayName(key), 'topic', s.id);
        addEdge(mid, tid, 'discussed', s.id, detail: t.summary);
        final pid = person(t.raisedBy);
        if (pid != null) addEdge(pid, tid, 'raised', s.id);
        meetingTopics.add((tid, TextSimilarity.tokenize(t.name)));
      }

      // Items are tied to the topics they mention so recall can be precise.
      void linkTopics(String itemId, String text) {
        final words = TextSimilarity.tokenize(text);
        for (final (tid, tokens) in meetingTopics) {
          if (tokens.isEmpty) continue;
          if (tokens.intersection(words).length / tokens.length >= 0.5) {
            addEdge(itemId, tid, 'about', s.id);
          }
        }
      }

      for (var i = 0; i < digest.decisions.length; i++) {
        final d = digest.decisions[i];
        final text = d.text;
        final id = 'd:${s.id}:$i';
        addNode(id, truncate(text, 44), 'decision', s.id,
            detail: d.rationale == null ? text : '$text — ${d.rationale}');
        addEdge(id, mid, 'decided in', s.id);
        linkTopics(id, text);
      }

      for (var i = 0; i < digest.actionItems.length; i++) {
        final a = digest.actionItems[i];
        final id = 'a:${s.id}:$i';
        final detail = '${a.owner == null ? '' : '${a.owner}: '}${a.task}${a.due == null ? '' : ' (due ${a.due})'}';
        addNode(id, truncate(a.task, 44), 'action', s.id, detail: detail);
        addEdge(id, mid, 'from', s.id);
        final pid = person(a.owner);
        if (pid != null) addEdge(pid, id, 'owns', s.id);
        linkTopics(id, a.task);
      }

      for (var i = 0; i < digest.openQuestions.length; i++) {
        final q = digest.openQuestions[i];
        final id = 'q:${s.id}:$i';
        final detail = q.asker == null ? q.question : '${q.asker} asked: ${q.question}';
        addNode(id, truncate(q.question, 44), 'question', s.id, detail: detail);
        addEdge(id, mid, 'unanswered in', s.id);
        final pid = person(q.asker);
        if (pid != null) addEdge(pid, id, 'asked', s.id);
        linkTopics(id, q.question);
      }
    }

    return DocGraph(nodes: nodes.values.toList(), edges: edges);
  }
}
