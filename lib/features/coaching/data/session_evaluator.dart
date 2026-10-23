import '../../../core/utils/text_similarity.dart';
import '../../ai_engine/domain/models/insight.dart';
import '../../history/domain/models/meeting_session.dart';
import 'session_metrics.dart';

class EvaluationResult {
  /// Per speaker label: (automatic seconds, manual seconds, relative error).
  final Map<String, ({double auto, double manual, double error})> talkTime;
  final int matchedUnanswered;
  final int annotatedUnanswered;
  final int flaggedUnanswered;
  final List<int> latenciesMs;

  const EvaluationResult({
    required this.talkTime,
    required this.matchedUnanswered,
    required this.annotatedUnanswered,
    required this.flaggedUnanswered,
    required this.latenciesMs,
  });

  double? get recall =>
      annotatedUnanswered == 0 ? null : matchedUnanswered / annotatedUnanswered;
  double? get precision =>
      flaggedUnanswered == 0 ? null : matchedUnanswered / flaggedUnanswered;
  double? get maxTalkTimeError => talkTime.isEmpty
      ? null
      : talkTime.values.map((v) => v.error).reduce((a, b) => a > b ? a : b);

  int? percentileLatency(double p) {
    if (latenciesMs.isEmpty) return null;
    final sorted = [...latenciesMs]..sort();
    final idx = ((sorted.length - 1) * p).round();
    return sorted[idx];
  }

  double? get shareWithin15s => latenciesMs.isEmpty
      ? null
      : latenciesMs.where((l) => l <= 15000).length / latenciesMs.length;

  static String _pct(double? v) => v == null ? 'n/a' : '${(v * 100).toStringAsFixed(0)}%';
  static String _ms(int? v) => v == null ? 'n/a' : '${(v / 1000).toStringAsFixed(1)}s';

  String report() {
    final b = StringBuffer()..writeln('== Talk time (target: error <= 10%) ==');
    talkTime.forEach((k, v) {
      b.writeln(
        '$k: auto ${v.auto.toStringAsFixed(1)}s vs manual ${v.manual.toStringAsFixed(1)}s '
        '-> ${_pct(v.error)} ${v.error <= 0.10 ? "PASS" : "FAIL"}',
      );
    });
    b
      ..writeln()
      ..writeln('== Unanswered questions (target: recall >= 75%) ==')
      ..writeln('annotated: $annotatedUnanswered, flagged: $flaggedUnanswered, matched: $matchedUnanswered')
      ..writeln('recall: ${_pct(recall)} ${(recall ?? 0) >= 0.75 ? "PASS" : "FAIL"}')
      ..writeln('precision: ${_pct(precision)}')
      ..writeln()
      ..writeln('== Insight latency (target: <= 15s) ==')
      ..writeln('n: ${latenciesMs.length}, median: ${_ms(percentileLatency(0.5))}, '
          'p90: ${_ms(percentileLatency(0.9))}, within 15s: ${_pct(shareWithin15s)}');
    return b.toString();
  }
}

class SessionEvaluator {
  /// A flagged insight matches an annotated question when their token overlap
  /// (Jaccard on title + description) reaches this.
  static const double matchThreshold = 0.25;

  /// [annotation] shape:
  /// `{"talkSeconds": {"Speaker 1": 62.0}, "unansweredQuestions": ["..."]}`
  static EvaluationResult evaluate(
    MeetingSession session,
    Map<String, dynamic> annotation,
  ) {
    final manual = (annotation['talkSeconds'] as Map<String, dynamic>? ?? {})
        .map((k, v) => MapEntry(k, (v as num).toDouble()));
    final metrics = {
      for (final m in metricsOf(session))
        m.speakerKey: m.talkTimeSec,
    };
    final talk = <String, ({double auto, double manual, double error})>{};
    manual.forEach((k, truth) {
      final auto = (metrics[k] ?? 0).toDouble();
      final err = truth == 0 ? (auto == 0 ? 0.0 : 1.0) : (auto - truth).abs() / truth;
      talk[k] = (auto: auto, manual: truth, error: err);
    });

    final truthQs = (annotation['unansweredQuestions'] as List<dynamic>? ?? [])
        .map((e) => e.toString())
        .toList();
    final flagged = session.insights
        .where((i) => i.category == InsightCategory.unansweredQuestion)
        .toList();

    final matchedTruth = <int>{};
    final matchedFlags = <int>{};
    for (var t = 0; t < truthQs.length; t++) {
      final tTokens = TextSimilarity.tokenize(truthQs[t]);
      for (var f = 0; f < flagged.length; f++) {
        final fTokens = TextSimilarity.tokenize('${flagged[f].title} ${flagged[f].description}');
        if (TextSimilarity.calculateJaccardSimilarity(tTokens, fTokens) >= matchThreshold) {
          matchedTruth.add(t);
          matchedFlags.add(f);
        }
      }
    }

    return EvaluationResult(
      talkTime: talk,
      matchedUnanswered: matchedTruth.length,
      annotatedUnanswered: truthQs.length,
      flaggedUnanswered: flagged.length,
      latenciesMs: [
        for (final i in session.insights)
          if (i.latencyMs != null) i.latencyMs!,
      ],
    );
  }
}
