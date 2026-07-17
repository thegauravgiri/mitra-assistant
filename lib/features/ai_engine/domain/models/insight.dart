enum InsightCategory {
  suggestion, // 💡 Talking points & recommendations
  keyPoint,   // 📋 Key context & facts mentioned
  question,   // ❓ Relevant questions to ask the client/team
  actionItem, // ✅ Action items & follow-ups
}

class Insight {
  final String id;
  final InsightCategory category;
  final String title;
  final String description;
  final DateTime timestamp;

  Insight({
    required this.id,
    required this.category,
    required this.title,
    required this.description,
    required this.timestamp,
  });
}
