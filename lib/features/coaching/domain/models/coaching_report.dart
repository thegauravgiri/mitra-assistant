import 'speaker_metrics.dart';

class CoachingReport {
  final List<SpeakerMetrics> metrics;

  /// Written review per speakerKey. Empty until Gemini has produced them.
  final Map<String, String> reviews;
  final DateTime generatedAt;

  const CoachingReport({
    required this.metrics,
    this.reviews = const {},
    required this.generatedAt,
  });

  CoachingReport copyWith({
    List<SpeakerMetrics>? metrics,
    Map<String, String>? reviews,
  }) =>
      CoachingReport(
        metrics: metrics ?? this.metrics,
        reviews: reviews ?? this.reviews,
        generatedAt: generatedAt,
      );

  Map<String, dynamic> toJson() => {
        'metrics': metrics.map((m) => m.toJson()).toList(),
        'reviews': reviews,
        'generatedAt': generatedAt.toIso8601String(),
      };

  factory CoachingReport.fromJson(Map<String, dynamic> json) => CoachingReport(
        metrics: (json['metrics'] as List<dynamic>? ?? [])
            .map((m) => SpeakerMetrics.fromJson(m as Map<String, dynamic>))
            .toList(),
        reviews: (json['reviews'] as Map<String, dynamic>? ?? {})
            .map((k, v) => MapEntry(k, v as String)),
        generatedAt: DateTime.parse(json['generatedAt'] as String),
      );
}
