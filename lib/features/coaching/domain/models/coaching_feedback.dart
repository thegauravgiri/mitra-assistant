/// One strength or improvement. Strengths usually carry an [evidence] quote;
/// improvements also carry a concrete [tip].
class FeedbackItem {
  final String title;
  final String? evidence;
  final String? tip;

  const FeedbackItem(this.title, {this.evidence, this.tip});

  Map<String, dynamic> toJson() => {
        'title': title,
        if (evidence != null) 'evidence': evidence,
        if (tip != null) 'tip': tip,
      };

  factory FeedbackItem.fromJson(Map<String, dynamic> j) => FeedbackItem(
        j['title'] as String? ?? '',
        evidence: j['evidence'] as String?,
        tip: j['tip'] as String?,
      );
}

/// Personalised post-meeting coaching for the user ("me").
class CoachingFeedback {
  final List<FeedbackItem> strengths;
  final List<FeedbackItem> improvements;
  final List<String> goalNotes;
  final DateTime generatedAt;

  const CoachingFeedback({
    this.strengths = const [],
    this.improvements = const [],
    this.goalNotes = const [],
    required this.generatedAt,
  });

  bool get isEmpty => strengths.isEmpty && improvements.isEmpty && goalNotes.isEmpty;

  Map<String, dynamic> toJson() => {
        'strengths': strengths.map((s) => s.toJson()).toList(),
        'improvements': improvements.map((s) => s.toJson()).toList(),
        'goalNotes': goalNotes,
        'generatedAt': generatedAt.toIso8601String(),
      };

  factory CoachingFeedback.fromJson(Map<String, dynamic> j) => CoachingFeedback(
        strengths: [for (final s in j['strengths'] as List? ?? const []) FeedbackItem.fromJson(s as Map<String, dynamic>)],
        improvements: [for (final s in j['improvements'] as List? ?? const []) FeedbackItem.fromJson(s as Map<String, dynamic>)],
        goalNotes: [for (final n in j['goalNotes'] as List? ?? const []) n.toString()],
        generatedAt: DateTime.tryParse(j['generatedAt'] as String? ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0),
      );
}
