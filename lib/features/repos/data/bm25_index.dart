import 'dart:math' as math;
import '../domain/models/repo_models.dart';
import 'identifier_tokenizer.dart';

class Bm25Hit {
  final CodeChunk chunk;
  final double score;
  final int matchedTerms; // how many distinct query words this chunk contains

  const Bm25Hit(this.chunk, this.score, this.matchedTerms);
}

/// In-memory inverted index (BM25) over code chunks, built for speed: a search
/// touches only the postings of the query's words, so it takes milliseconds
/// even over tens of thousands of chunks.
///
/// Where a word appears matters: declared names count 3x, the file path 2x,
/// the plain-English notes 1.5x, plain code 1x. Test chunks get a small boost
/// because test names literally describe scenarios.
class Bm25Index {
  static const double k1 = 1.2;
  static const double b = 0.75;
  static const double testBoost = 1.25;
  static const double docBoost = 1.0;
  static const double synonymWeight = 0.55; // a synonym counts for less than the word itself

  final List<CodeChunk> chunks;
  final Map<String, List<int>> _docs = {};
  final Map<String, List<double>> _tfs = {};
  final List<double> _len = [];
  double _avgLen = 1;

  Bm25Index._(this.chunks);

  static final Bm25Index empty = Bm25Index._(const []);

  static Bm25Index build(List<CodeChunk> chunks) {
    final index = Bm25Index._(chunks);
    for (var i = 0; i < chunks.length; i++) {
      index._add(i);
    }
    index._finish();
    return index;
  }

  /// Same as [build] but yields to the UI between batches, so indexing a large
  /// repository never freezes the app.
  static Future<Bm25Index> buildAsync(List<CodeChunk> chunks, {int batch = 1500}) async {
    final index = Bm25Index._(chunks);
    for (var i = 0; i < chunks.length; i++) {
      index._add(i);
      if (i % batch == batch - 1) await Future<void>.delayed(Duration.zero);
    }
    index._finish();
    return index;
  }

  void _add(int i) {
    final c = chunks[i];
    final tf = <String, double>{};
    void count(String text, double weight) {
      for (final t in IdentifierTokenizer.tokens(text)) {
        tf[t] = (tf[t] ?? 0) + weight;
      }
    }

    count(c.text, 1);
    for (final s in c.symbols) {
      count(s, 3);
    }
    count(c.path, 2);
    if (c.summary != null) count(c.summary!, 1.5);

    var len = 0.0;
    tf.forEach((term, f) {
      (_docs[term] ??= []).add(i);
      (_tfs[term] ??= []).add(f);
      len += f;
    });
    _len.add(len);
  }

  void _finish() {
    _avgLen = _len.isEmpty ? 1 : _len.reduce((a, b) => a + b) / _len.length;
    if (_avgLen <= 0) _avgLen = 1;
  }

  bool get isEmpty => chunks.isEmpty;

  /// Best matches for [query], most relevant first. [repoIds] limits the
  /// search to those repositories; [kind] to one kind of chunk.
  List<Bm25Hit> search(String query, {int topK = 8, Set<String>? repoIds, ChunkKind? kind}) {
    if (chunks.isEmpty) return const [];
    final terms = IdentifierTokenizer.uniqueTokens(query);
    if (terms.isEmpty) return const [];

    // the words themselves, then their plain-speech/code synonyms at lower weight
    final weights = <String, double>{for (final t in terms) t: 1.0};
    for (final t in terms) {
      for (final syn in IdentifierTokenizer.synonymsOf(t)) {
        weights.putIfAbsent(syn, () => synonymWeight);
      }
    }

    final n = chunks.length;
    final scores = <int, double>{};
    final matched = <int, int>{};
    for (final entry in weights.entries) {
      final term = entry.key;
      final w = entry.value;
      final docs = _docs[term];
      if (docs == null) continue;
      final idf = math.log(1 + (n - docs.length + 0.5) / (docs.length + 0.5));
      final tfs = _tfs[term]!;
      for (var p = 0; p < docs.length; p++) {
        final d = docs[p];
        final f = tfs[p];
        final s = idf * (f * (k1 + 1)) / (f + k1 * (1 - b + b * _len[d] / _avgLen));
        scores[d] = (scores[d] ?? 0) + s * w;
        if (w == 1.0) matched[d] = (matched[d] ?? 0) + 1;
      }
    }

    final hits = <Bm25Hit>[];
    scores.forEach((d, s) {
      if (!matched.containsKey(d)) return; // matched only through synonyms: not enough
      final c = chunks[d];
      if (repoIds != null && !repoIds.contains(c.repoId)) return;
      if (kind != null && c.kind != kind) return;
      final boost = c.kind == ChunkKind.test ? testBoost : (c.kind == ChunkKind.doc ? docBoost : 1.0);
      hits.add(Bm25Hit(c, s * boost, matched[d]!));
    });
    hits.sort((a, b) => b.score.compareTo(a.score));
    return hits.length > topK ? hits.sublist(0, topK) : hits;
  }
}
