import 'package:flutter_test/flutter_test.dart';
import 'package:mitra_assistant/features/transcription/domain/models/transcript_entry.dart';
import 'package:mitra_assistant/features/transcription/providers/transcription_providers.dart';
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

    test('TranscriptionState copyWith preserves error unless explicitly cleared', () {
      final stateWithError = TranscriptionState(
        entries: [],
        error: 'Network connection failed',
      );

      // Calling copyWith without passing error preserves the error
      final updatedState = stateWithError.copyWith(
        currentInterim: 'Hello...',
      );
      expect(updatedState.error, equals('Network connection failed'));

      // Explicitly passing error: null clears it
      final clearedState = updatedState.copyWith(error: null);
      expect(clearedState.error, isNull);
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
