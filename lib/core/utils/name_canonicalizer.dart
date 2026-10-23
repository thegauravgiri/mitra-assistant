import '../constants/app_constants.dart';
import 'text_similarity.dart';

/// Gives near-identical names one canonical key ("Q3 budget" == "q3 Budget" ==
/// "Q3 budgets"-ish by token overlap), so the same entity found in different
/// places becomes a single graph node.
class NameCanonicalizer {
  final double threshold;
  final Map<String, String> _display = {}; // key -> first-seen display name
  final Map<String, Set<String>> _tokens = {};

  NameCanonicalizer({this.threshold = AppConstants.graphNodeMergeSimilarity});

  /// Canonical key for [name], registering it if it is new. Empty string for
  /// names with no usable characters.
  String canonical(String name) {
    final norm = TextSimilarity.normalize(name);
    if (norm.isEmpty) return '';
    if (_display.containsKey(norm)) return norm;

    final t = TextSimilarity.tokenize(name);
    if (t.isNotEmpty) {
      for (final entry in _tokens.entries) {
        if (TextSimilarity.calculateJaccardSimilarity(t, entry.value) >= threshold) {
          return entry.key;
        }
      }
    }
    _display[norm] = name.trim();
    _tokens[norm] = t;
    return norm;
  }

  /// Like [canonical] but never registers a new name: returns the key of an
  /// already-seen name that [name] matches, or null.
  String? find(String name) {
    final norm = TextSimilarity.normalize(name);
    if (norm.isEmpty) return null;
    if (_display.containsKey(norm)) return norm;
    final t = TextSimilarity.tokenize(name);
    if (t.isEmpty) return null;
    for (final entry in _tokens.entries) {
      if (TextSimilarity.calculateJaccardSimilarity(t, entry.value) >= threshold) return entry.key;
    }
    return null;
  }

  String displayName(String key) => _display[key] ?? key;
}
