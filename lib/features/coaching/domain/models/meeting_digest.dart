String? _s(dynamic v) {
  if (v is! String) return null;
  final t = v.trim();
  return t.isEmpty || t.toLowerCase() == 'null' ? null : t;
}

class DigestTopic {
  final String name;
  final String? raisedBy;

  /// What was said about this topic in THIS meeting: positions, numbers,
  /// disagreements, conclusion. Recall shows it when the topic comes up again.
  final String? summary;

  const DigestTopic(this.name, {this.raisedBy, this.summary});

  Map<String, dynamic> toJson() => {
        'name': name,
        if (raisedBy != null) 'raisedBy': raisedBy,
        if (summary != null) 'summary': summary,
      };

  factory DigestTopic.fromJson(Map<String, dynamic> j) =>
      DigestTopic(j['name'] as String? ?? '', raisedBy: _s(j['raisedBy']), summary: _s(j['summary']));
}

class DigestDecision {
  final String text;
  final String? rationale; // why, or the context it was decided in
  final String? evidence; // short verbatim quote from the transcript

  const DigestDecision(this.text, {this.rationale, this.evidence});

  Map<String, dynamic> toJson() => {
        'text': text,
        if (rationale != null) 'rationale': rationale,
        if (evidence != null) 'evidence': evidence,
      };

  /// Accepts a plain string (notes saved before decisions had details) or a map.
  factory DigestDecision.fromJson(dynamic j) {
    if (j is Map) {
      return DigestDecision(
        _s(j['text']) ?? _s(j['decision']) ?? '',
        rationale: _s(j['rationale']),
        evidence: _s(j['evidence']),
      );
    }
    return DigestDecision(j.toString());
  }
}

class DigestAction {
  final String? owner;
  final String task;
  final String? due; // as said: "by Friday", "next sprint"
  final String? evidence;

  const DigestAction(this.task, {this.owner, this.due, this.evidence});

  Map<String, dynamic> toJson() => {
        'task': task,
        if (owner != null) 'owner': owner,
        if (due != null) 'due': due,
        if (evidence != null) 'evidence': evidence,
      };

  factory DigestAction.fromJson(Map<String, dynamic> j) => DigestAction(
        j['task'] as String? ?? '',
        owner: _s(j['owner']),
        due: _s(j['due']),
        evidence: _s(j['evidence']),
      );
}

class DigestQuestion {
  final String? asker;
  final String question;
  final String? context; // why it came up

  const DigestQuestion(this.question, {this.asker, this.context});

  Map<String, dynamic> toJson() => {
        'question': question,
        if (asker != null) 'asker': asker,
        if (context != null) 'context': context,
      };

  factory DigestQuestion.fromJson(Map<String, dynamic> j) =>
      DigestQuestion(j['question'] as String? ?? '', asker: _s(j['asker']), context: _s(j['context']));
}

/// What a meeting produced. One structured pass (map-reduce for long meetings)
/// fills it; the History outcomes, the cross-meeting graph and live recall all
/// read it, so it has to be descriptive enough to stand in for the meeting.
class MeetingDigest {
  /// Overview of the whole meeting: purpose, how it unfolded, outcome.
  final String summary;
  final List<DigestTopic> topics;
  final List<DigestDecision> decisions;
  final List<DigestAction> actionItems;
  final List<DigestQuestion> openQuestions;
  final List<String> risks; // concerns and blockers raised
  final List<String> keyFacts; // figures, dates, prices, names stated
  final DateTime generatedAt;

  const MeetingDigest({
    this.summary = '',
    this.topics = const [],
    this.decisions = const [],
    this.actionItems = const [],
    this.openQuestions = const [],
    this.risks = const [],
    this.keyFacts = const [],
    required this.generatedAt,
  });

  bool get isEmpty =>
      summary.isEmpty &&
      topics.isEmpty &&
      decisions.isEmpty &&
      actionItems.isEmpty &&
      openQuestions.isEmpty &&
      risks.isEmpty &&
      keyFacts.isEmpty;

  Map<String, dynamic> toJson() => {
        'summary': summary,
        'topics': topics.map((t) => t.toJson()).toList(),
        'decisions': decisions.map((d) => d.toJson()).toList(),
        'actionItems': actionItems.map((a) => a.toJson()).toList(),
        'openQuestions': openQuestions.map((q) => q.toJson()).toList(),
        if (risks.isNotEmpty) 'risks': risks,
        if (keyFacts.isNotEmpty) 'keyFacts': keyFacts,
        'generatedAt': generatedAt.toIso8601String(),
      };

  factory MeetingDigest.fromJson(Map<String, dynamic> j) => MeetingDigest(
        summary: j['summary'] as String? ?? '',
        topics: [for (final t in j['topics'] as List? ?? const []) DigestTopic.fromJson(t as Map<String, dynamic>)],
        decisions: [for (final d in j['decisions'] as List? ?? const []) DigestDecision.fromJson(d)],
        actionItems: [for (final a in j['actionItems'] as List? ?? const []) DigestAction.fromJson(a as Map<String, dynamic>)],
        openQuestions: [for (final q in j['openQuestions'] as List? ?? const []) DigestQuestion.fromJson(q as Map<String, dynamic>)],
        risks: [for (final r in j['risks'] as List? ?? const []) r.toString()],
        keyFacts: [for (final f in j['keyFacts'] as List? ?? const []) f.toString()],
        generatedAt: DateTime.tryParse(j['generatedAt'] as String? ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0),
      );
}
