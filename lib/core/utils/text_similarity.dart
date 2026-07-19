/// Utility class providing reusable text normalization, tokenization,
/// and similarity functions across AI engines and document relevance matchers.
class TextSimilarity {
  static const Set<String> stopWords = {
    'the',
    'a',
    'an',
    'and',
    'to',
    'in',
    'of',
    'for',
    'with',
    'on',
    'at',
    'by',
    'from',
    'is',
    'are',
    'was',
    'were',
    'be',
    'been',
    'should',
    'could',
    'would',
    'that',
    'this',
    'it',
    'as',
    'or',
    'we',
    'you',
    'i',
    'our',
    'your',
  };

  static String normalize(String input) {
    return input.toLowerCase().replaceAll(RegExp(r'[^\w\s]'), '').trim();
  }

  static Set<String> tokenize(String text) {
    final normalized = normalize(text);
    if (normalized.isEmpty) return {};
    return normalized
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty && !stopWords.contains(word))
        .toSet();
  }

  static double calculateJaccardSimilarity(Set<String> setA, Set<String> setB) {
    if (setA.isEmpty || setB.isEmpty) return 0.0;
    final intersection = setA.intersection(setB).length;
    final union = setA.union(setB).length;
    if (union == 0) return 0.0;
    return intersection / union;
  }
}
