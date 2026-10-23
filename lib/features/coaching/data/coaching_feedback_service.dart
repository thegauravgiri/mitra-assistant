import 'dart:convert';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/text_similarity.dart';
import '../../ai_engine/data/prompt_templates.dart';
import '../domain/models/coaching_feedback.dart';
import 'digest_service.dart';
import 'goal_evaluator.dart';
import 'indicator_evaluator.dart';

/// Builds personalised coaching for one person. The LLM call is injected so
/// summarising, parsing and evidence checking are testable without network.
class CoachingFeedbackService {
  static const int maxEvidenceWords = 20;

  /// Plain-text facts handed to the model: indicators (with status and the
  /// person's own recent average) and goal results.
  static String summarize({
    required List<Indicator> indicators,
    required Map<String, double?> baselines,
    required List<GoalResult> goals,
  }) {
    final b = StringBuffer('Indicators for this meeting:\n');
    for (final i in indicators) {
      final base = baselines[i.id];
      final baseText = base == null ? '' : '; your average over recent meetings: ${base.toStringAsFixed(1)}';
      b.writeln('- ${i.label}: ${i.display} (${i.status.name}; ${i.rangeText}$baseText)');
    }
    b.writeln();
    if (goals.isEmpty) {
      b.writeln('Goals: none set.');
    } else {
      b.writeln('Goals:');
      for (final g in goals) {
        final state = g.met == null ? 'not measurable' : (g.met! ? 'MET' : 'NOT met');
        b.writeln('- ${g.goal.description}: $state (${g.valueText})');
      }
    }
    return b.toString();
  }

  Future<CoachingFeedback> generate({
    required String name,
    required String myText,
    required String labelledTranscript,
    required String summary,
    required Future<String> Function(String systemPrompt, String prompt) generate,
    String meetingOverview = '',
    DateTime? now,
  }) async {
    final raw = await generate(
      PromptTemplates.coachingSystemPrompt,
      PromptTemplates.buildCoachingPrompt(
        name: name,
        summary: summary,
        transcript: DigestService.trim(labelledTranscript),
        meetingOverview: meetingOverview,
      ),
    );
    final feedback = parse(raw, myText: myText, now: now);
    if (feedback == null) throw Exception('Gemini returned no usable coaching');
    return feedback;
  }

  /// Parses the model output and **drops any quote that is not actually in
  /// the coachee's own lines**, so an invented quote can never be shown.
  static CoachingFeedback? parse(String raw, {required String myText, DateTime? now}) {
    var text = raw.trim();
    if (text.isEmpty) return null;
    text = text
        .replaceAll(RegExp(r'^```(json)?\s*', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s*```$'), '');

    dynamic parsed;
    try {
      parsed = jsonDecode(text);
    } catch (_) {
      final m = RegExp(r'\{.*\}', dotAll: true).firstMatch(text);
      if (m != null) {
        try {
          parsed = jsonDecode(m.group(0)!);
        } catch (_) {}
      }
    }
    if (parsed is! Map) return null;

    final haystack = TextSimilarity.normalize(myText);

    String? verified(dynamic quote) {
      if (quote is! String) return null;
      final q = quote.trim();
      if (q.isEmpty) return null;
      final norm = TextSimilarity.normalize(q);
      if (norm.isEmpty) return null;
      if (norm.split(RegExp(r'\s+')).length > maxEvidenceWords) return null;
      return haystack.contains(norm) ? q : null;
    }

    String? str(dynamic v) {
      if (v is! String) return null;
      final t = v.trim();
      return t.isEmpty ? null : t;
    }

    List<FeedbackItem> items(dynamic list, int max, {required bool tip}) {
      if (list is! List) return [];
      final out = <FeedbackItem>[];
      for (final item in list) {
        if (item is! Map) continue;
        final title = str(item['title']);
        if (title == null) continue;
        out.add(FeedbackItem(
          title,
          evidence: verified(item['evidence']),
          tip: tip ? str(item['tip']) : null,
        ));
        if (out.length == max) break;
      }
      return out;
    }

    final feedback = CoachingFeedback(
      strengths: items(parsed['strengths'], 2, tip: false),
      improvements: items(parsed['improvements'], 3, tip: true),
      goalNotes: [
        for (final n in parsed['goalNotes'] as List? ?? const [])
          if (str(n) != null) str(n)!,
      ].take(AppConstants.maxGoals).toList(),
      generatedAt: now ?? DateTime.now(),
    );
    return feedback.isEmpty ? null : feedback;
  }
}
