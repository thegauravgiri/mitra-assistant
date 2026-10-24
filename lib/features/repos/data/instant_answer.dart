import '../../ai_engine/domain/models/insight.dart';
import '../../transcription/domain/models/transcript_entry.dart';
import 'repo_retrieval.dart';

/// Pieces of the "answer in milliseconds" path that need no AI call.
class InstantAnswer {
  /// The text to search with: the client's question, plus the line before it
  /// when the question is short and leans on it ("And what about refunds?").
  static String queryFor(List<TranscriptEntry> entries, TranscriptEntry question) {
    final i = entries.indexWhere((e) => e.id == question.id);
    final wordCount = question.text.trim().split(RegExp(r'\s+')).length;
    if (wordCount < 8 && i > 0) {
      return '${entries[i - 1].text} ${question.text}';
    }
    return question.text;
  }

  /// A ready-to-show insight if the repositories already hold a plain-English
  /// answer: a prepared scenario answer first, otherwise the notes of the best
  /// matching file. Null when all we have is raw code, because that is not
  /// something to read out to a client; the model answers that case.
  static Insight? build(RepoContext ctx, {DateTime? now}) {
    final at = now ?? DateTime.now();
    final s = ctx.scenario;
    if (s != null) {
      final cited = s.sources.isEmpty ? '' : ' (from ${ctx.scenarioRepo ?? 'your repo'}: ${s.sources.take(2).join(', ')})';
      return Insight(
        id: 'repo-scenario-${s.question.hashCode}',
        category: InsightCategory.answer,
        title: _short('Ready answer: ${s.question}'),
        description: '${s.answer}$cited',
        timestamp: at,
      );
    }
    final notes = ctx.leadNotes;
    if (notes != null && notes.isNotEmpty && ctx.leadRef != null) {
      return Insight(
        id: 'repo-notes-${ctx.leadRef.hashCode}',
        category: InsightCategory.answer,
        title: _short('From your code: ${ctx.leadRef!.split('/').last.split(':').first}'),
        description: '${notes.length > 280 ? '${notes.substring(0, 279)}…' : notes} (${ctx.leadRef})',
        timestamp: at,
      );
    }
    return null;
  }

  static String _short(String t) => t.length > 60 ? '${t.substring(0, 59)}…' : t;
}
