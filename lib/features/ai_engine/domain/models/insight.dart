enum InsightCategory {
  suggestion, // 💡 Talking points & recommendations
  keyPoint,   // 📋 Key context & facts mentioned
  question,   // ❓ Relevant questions to ask the client/team
  actionItem, // ✅ Action items & follow-ups
  answer,     // 💬 Answer to a question that was just asked
  unansweredQuestion, // 🔔 A question asked earlier that nobody answered
}

class Insight {
  final String id;
  final InsightCategory category;
  final String title;
  final String description;
  final DateTime timestamp;

  /// Time from the newest final transcript line to this insight arriving.
  /// Null for insights not produced by the periodic analysis (e.g. Q&A).
  final int? latencyMs;

  Insight({
    required this.id,
    required this.category,
    required this.title,
    required this.description,
    required this.timestamp,
    this.latencyMs,
  });

  Insight copyWith({int? latencyMs}) => Insight(
        id: id,
        category: category,
        title: title,
        description: description,
        timestamp: timestamp,
        latencyMs: latencyMs ?? this.latencyMs,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'category': category.name,
        'title': title,
        'description': description,
        'timestamp': timestamp.toIso8601String(),
        if (latencyMs != null) 'latencyMs': latencyMs,
      };

  factory Insight.fromJson(Map<String, dynamic> json) => Insight(
        id: json['id'] as String? ?? '',
        category: InsightCategory.values.firstWhere(
          (c) => c.name == json['category'],
          orElse: () => InsightCategory.suggestion,
        ),
        title: json['title'] as String? ?? '',
        description: json['description'] as String? ?? '',
        timestamp: DateTime.parse(json['timestamp'] as String),
        latencyMs: (json['latencyMs'] as num?)?.toInt(),
      );
}
