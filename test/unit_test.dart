import 'package:flutter_test/flutter_test.dart';
import 'package:mitra_assistant/features/transcription/domain/models/transcript_entry.dart';
import 'package:mitra_assistant/features/ai_engine/domain/models/insight.dart';

void main() {
  group('Data Models Unit Tests', () {
    test('TranscriptEntry creation and copyWith', () {
      final now = DateTime.now();
      final entry = TranscriptEntry(
        id: '123',
        text: 'Hello world',
        timestamp: now,
        isFinal: true,
      );

      expect(entry.id, '123');
      expect(entry.text, 'Hello world');
      expect(entry.isFinal, isTrue);

      final updated = entry.copyWith(text: 'Updated text');
      expect(updated.id, '123');
      expect(updated.text, 'Updated text');
    });

    test('Insight category properties', () {
      final insight = Insight(
        id: 'abc',
        category: InsightCategory.suggestion,
        title: 'Talking Point',
        description: 'Mention pricing strategy',
        timestamp: DateTime.now(),
      );

      expect(insight.category, InsightCategory.suggestion);
      expect(insight.title, 'Talking Point');
      expect(insight.description, 'Mention pricing strategy');
    });
  });
}
