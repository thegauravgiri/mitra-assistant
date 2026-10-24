import 'dart:convert';
import '../../../core/utils/logger.dart';
import '../../ai_engine/data/prompt_templates.dart';
import '../domain/models/repo_models.dart';
import 'identifier_tokenizer.dart';

typedef NotesGenerate = Future<String> Function(String systemPrompt, String prompt);

class FileNotes {
  final String summary;
  final List<String> behaviours;
  final List<ScenarioCard> scenarios;

  const FileNotes({required this.summary, this.behaviours = const [], this.scenarios = const []});

  /// One block of plain text stored on each chunk of the file and indexed.
  String get text {
    final b = behaviours.isEmpty ? '' : ' Behaviour: ${behaviours.join('; ')}';
    final t = '$summary$b'.trim();
    return t.length > 900 ? '${t.substring(0, 899)}…' : t;
  }
}

class NotesResult {
  final Map<String, FileNotes> notes; // by file path
  final int failedBatches;

  const NotesResult(this.notes, this.failedBatches);
}

/// Writes plain-English notes for the most important files of a repository, once.
/// This is what lets a client's wording ("what if the payment fails?") find code
/// whose names never use those words, and it produces ready-made scenario
/// answers, all before the meeting so nothing slow happens during it.
class RepoSummarizer {
  static const int maxFiles = 120;
  static const int maxFileChars = 3500;
  static const int batchChars = 12000;
  static const int maxFilesPerBatch = 6;
  static const int maxScenarios = 60;

  static const List<String> _importantNames = [
    'service', 'controller', 'handler', 'manager', 'provider', 'repository', 'router', 'route', 'api', 'main',
    'app', 'payment', 'billing', 'auth', 'login', 'order', 'checkout', 'sync', 'queue', 'worker', 'policy', 'rule',
  ];

  /// Files worth explaining, most important first. Skips docs (already prose),
  /// tiny files, and files that already have notes unless [force].
  static List<(String path, String text)> selectFiles(RepoData data, {int limit = maxFiles, bool force = false}) {
    final byPath = <String, List<CodeChunk>>{};
    for (final c in data.chunks) {
      if (c.kind == ChunkKind.doc) continue;
      (byPath[c.path] ??= []).add(c);
    }
    final scored = <(String, String, double)>[];
    byPath.forEach((path, cs) {
      if (!force && cs.any((c) => c.summary != null)) return;
      final text = cs.map((c) => c.text).join('\n');
      if (text.length < 300) return;
      var score = text.length.clamp(0, 4000).toDouble();
      final lower = path.toLowerCase();
      for (final n in _importantNames) {
        if (lower.contains(n)) {
          score += 800;
          break;
        }
      }
      if (cs.first.kind == ChunkKind.test) score -= 300; // source first: its behaviour is what gets explained
      scored.add((path, text.length > maxFileChars ? '${text.substring(0, maxFileChars)}\n…' : text, score));
    });
    scored.sort((a, b) => b.$3.compareTo(a.$3));
    return [for (final s in scored.take(limit)) (s.$1, s.$2)];
  }

  /// Groups files into model calls of at most [batchChars] / [maxFilesPerBatch].
  static List<List<(String, String)>> batches(List<(String path, String text)> files) {
    final out = <List<(String, String)>>[];
    var cur = <(String, String)>[];
    var size = 0;
    for (final f in files) {
      if (cur.isNotEmpty && (size + f.$2.length > batchChars || cur.length >= maxFilesPerBatch)) {
        out.add(cur);
        cur = [];
        size = 0;
      }
      cur.add(f);
      size += f.$2.length;
    }
    if (cur.isNotEmpty) out.add(cur);
    return out;
  }

  static Future<NotesResult> run(
    String repoName,
    List<(String path, String text)> files, {
    required NotesGenerate generate,
    void Function(int done, int total)? onProgress,
  }) async {
    final notes = <String, FileNotes>{};
    var failed = 0;
    final groups = batches(files);
    for (var i = 0; i < groups.length; i++) {
      try {
        final raw = await generate(
          PromptTemplates.repoNotesSystemPrompt,
          PromptTemplates.buildRepoNotesPrompt(repoName, groups[i]),
        );
        notes.addAll(parse(raw, allowedPaths: {for (final f in groups[i]) f.$1}));
      } catch (e) {
        failed++;
        AppLogger.error('Repo notes batch ${i + 1}/${groups.length} failed', e);
      }
      onProgress?.call(i + 1, groups.length);
    }
    return NotesResult(notes, failed);
  }

  /// Defensive like the other Gemini parsers. Only paths we asked about are kept.
  static Map<String, FileNotes> parse(String raw, {required Set<String> allowedPaths}) {
    var text = raw.trim();
    if (text.isEmpty) return const {};
    text = text.replaceAll(RegExp(r'^```(json)?\s*', caseSensitive: false), '').replaceAll(RegExp(r'\s*```$'), '');
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
    final list = parsed is Map ? parsed['files'] : (parsed is List ? parsed : null);
    if (list is! List) return const {};

    String? str(dynamic v) {
      if (v is! String) return null;
      final t = v.trim();
      return t.isEmpty ? null : t;
    }

    final out = <String, FileNotes>{};
    for (final f in list) {
      if (f is! Map) continue;
      final path = str(f['path']);
      final summary = str(f['summary']);
      if (path == null || summary == null || !allowedPaths.contains(path)) continue;
      out[path] = FileNotes(
        summary: summary,
        behaviours: [for (final b in f['behaviours'] as List? ?? const []) if (str(b) != null) str(b)!].take(6).toList(),
        scenarios: [
          for (final s in f['scenarios'] as List? ?? const [])
            if (s is Map && str(s['question']) != null && str(s['answer']) != null)
              ScenarioCard(question: str(s['question'])!, answer: str(s['answer'])!, sources: [path]),
        ].take(3).toList(),
      );
    }
    return out;
  }

  /// Attaches the notes to every chunk of each file and merges the scenario
  /// cards (de-duplicated by meaning, capped).
  static RepoData apply(RepoData data, Map<String, FileNotes> notes) {
    final chunks = [
      for (final c in data.chunks) notes.containsKey(c.path) ? c.withSummary(notes[c.path]!.text) : c,
    ];

    final cards = [...data.scenarios];
    final seen = {for (final c in cards) IdentifierTokenizer.uniqueTokens(c.question).join(' ')};
    for (final n in notes.values) {
      for (final s in n.scenarios) {
        if (seen.add(IdentifierTokenizer.uniqueTokens(s.question).join(' '))) cards.add(s);
      }
    }
    final summarised = {for (final c in chunks) if (c.summary != null) c.path}.length;
    return data.copyWith(
      chunks: chunks,
      scenarios: cards.take(maxScenarios).toList(),
      source: data.source.copyWith(summarisedFiles: summarised),
    );
  }
}
