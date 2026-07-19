import 'package:flutter_test/flutter_test.dart';
import 'package:mitra_assistant/core/utils/text_similarity.dart';

void main() {
  group('TextSimilarity Utility Tests', () {
    test('normalize removes special characters and lowers case', () {
      expect(TextSimilarity.normalize('Hello, World! #123'), 'hello world 123');
    });

    test('tokenize filters out stop words and returns unique terms', () {
      final tokens = TextSimilarity.tokenize('The quick brown fox jumps over the lazy dog');
      expect(tokens, containsAll({'quick', 'brown', 'fox', 'jumps', 'over', 'lazy', 'dog'}));
      expect(tokens, isNot(contains('the')));
    });

    test('calculateJaccardSimilarity computes correct token overlap ratio', () {
      final setA = {'apple', 'banana', 'cherry'};
      final setB = {'banana', 'cherry', 'date'};

      // Intersection = 2 ('banana', 'cherry')
      // Union = 4 ('apple', 'banana', 'cherry', 'date')
      // Jaccard = 2 / 4 = 0.5
      final sim = TextSimilarity.calculateJaccardSimilarity(setA, setB);
      expect(sim, equals(0.5));
    });
  });
}
