import '../domain/models/repo_models.dart';
import 'bm25_index.dart';
import 'identifier_tokenizer.dart';

class RepoSourceRef {
  final String repoName;
  final String ref; // path:start-end
  final ChunkKind kind;

  const RepoSourceRef(this.repoName, this.ref, this.kind);

  @override
  String toString() => '$repoName/$ref';
}

/// What the repositories know about a question, ready to hand to the model (or
/// to show instantly).
class RepoContext {
  final String text; // prompt block; '' when nothing relevant was found
  final List<RepoSourceRef> sources;
  final ScenarioCard? scenario; // a ready answer written in advance, if one matches
  final String? scenarioRepo;
  final double topScore;

  /// Plain-English account from the best-matching file's notes (no code), if it
  /// has any: safe to show immediately without asking the model.
  final String? leadNotes;
  final String? leadRef;

  const RepoContext({
    this.text = '',
    this.sources = const [],
    this.scenario,
    this.scenarioRepo,
    this.topScore = 0,
    this.leadNotes,
    this.leadRef,
  });

  bool get isEmpty => text.isEmpty && scenario == null;
  static const RepoContext none = RepoContext();
}

/// Searches the indexed repositories. Pure and synchronous: a call is a few
/// map lookups, so it is safe to run on every question while a call is live.
class RepoRetrieval {
  final Bm25Index index;
  final Map<String, String> repoNames; // id -> display name
  final List<(String repoId, ScenarioCard card)> scenarios;

  RepoRetrieval({required this.index, required this.repoNames, this.scenarios = const []});

  static const double minRelativeScore = 0.4; // vs the best hit
  static const double scenarioMatch = 0.55;

  /// [maxChars] caps the prompt block; [maxChunks] caps the pieces.
  RepoContext retrieve(String query, {int maxChars = 2000, int maxChunks = 5, Set<String>? repoIds}) {
    final qTokens = IdentifierTokenizer.uniqueTokens(query);
    if (qTokens.isEmpty) return RepoContext.none;

    final scenario = _matchScenario(qTokens, repoIds);

    var hits = index.search(query, topK: 12, repoIds: repoIds);
    if (hits.isEmpty) {
      return scenario == null ? RepoContext.none : RepoContext(scenario: scenario.$2, scenarioRepo: repoNames[scenario.$1]);
    }

    // Several query words should agree before a chunk counts as relevant;
    // a single shared word is usually a coincidence.
    final need = qTokens.length >= 4 ? 2 : 1;
    final top = hits.first.score;
    hits = [
      for (final h in hits)
        if (h.score >= top * minRelativeScore && h.matchedTerms >= need) h,
    ];
    if (hits.isEmpty) {
      return scenario == null ? RepoContext.none : RepoContext(scenario: scenario.$2, scenarioRepo: repoNames[scenario.$1]);
    }

    final chosen = <Bm25Hit>[...hits.take(maxChunks)];

    // A scenario question is best answered by a test AND the code it exercises:
    // bring whichever of the two is missing, from the same repository.
    final lead = chosen.first.chunk;
    final sameRepo = {lead.repoId};
    Bm25Hit? companion;
    if (lead.kind == ChunkKind.test) {
      final probe = lead.text.length > 400 ? lead.text.substring(0, 400) : lead.text;
      companion = _firstNew(index.search(probe, topK: 3, repoIds: sameRepo, kind: ChunkKind.code), chosen);
    } else if (lead.symbols.isNotEmpty) {
      companion = _firstNew(index.search(lead.symbols.join(' '), topK: 3, repoIds: sameRepo, kind: ChunkKind.test), chosen);
    }
    if (companion != null) {
      if (chosen.length >= maxChunks) chosen.removeLast();
      chosen.add(companion);
    }

    final buf = StringBuffer();
    final sources = <RepoSourceRef>[];
    final perChunk = (maxChars / chosen.length).floor().clamp(350, 900);
    for (final h in chosen) {
      final c = h.chunk;
      final name = repoNames[c.repoId] ?? 'repo';
      final entry = StringBuffer('[$name] ${c.ref}${c.kind == ChunkKind.test ? ' (test)' : ''}\n');
      if (c.summary != null) {
        final s = c.summary!;
        entry.writeln('In plain English: ${s.length > 320 ? '${s.substring(0, 319)}…' : s}');
      }
      final room = perChunk - entry.length;
      if (room > 120) {
        final code = c.text;
        entry.writeln(code.length > room ? '${code.substring(0, room - 1)}…' : code);
      }
      entry.writeln();
      if (buf.length + entry.length > maxChars && sources.isNotEmpty) break;
      buf.write(entry);
      sources.add(RepoSourceRef(name, c.ref, c.kind));
    }

    final leadChunk = chosen.first.chunk;
    return RepoContext(
      text: buf.toString().trim(),
      sources: sources,
      scenario: scenario?.$2,
      scenarioRepo: scenario == null ? null : repoNames[scenario.$1],
      topScore: top,
      leadNotes: leadChunk.summary,
      leadRef: '${repoNames[leadChunk.repoId] ?? 'repo'}/${leadChunk.ref}',
    );
  }

  Bm25Hit? _firstNew(List<Bm25Hit> candidates, List<Bm25Hit> chosen) {
    for (final c in candidates) {
      if (!chosen.any((x) => identical(x.chunk, c.chunk))) return c;
    }
    return null;
  }

  /// A card whose question shares most of its meaning with [qTokens] (Dice
  /// similarity on stems, at least two shared words).
  (String, ScenarioCard)? _matchScenario(Set<String> qTokens, Set<String>? repoIds) {
    (String, ScenarioCard)? best;
    var bestScore = 0.0;
    for (final s in scenarios) {
      if (repoIds != null && !repoIds.contains(s.$1)) continue;
      final c = IdentifierTokenizer.uniqueTokens(s.$2.question);
      if (c.isEmpty) continue;
      final shared = qTokens.intersection(c).length;
      if (shared < 2) continue;
      final dice = 2 * shared / (qTokens.length + c.length);
      if (dice >= scenarioMatch && dice > bestScore) {
        bestScore = dice;
        best = s;
      }
    }
    return best;
  }
}
