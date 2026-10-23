import 'package:flutter_test/flutter_test.dart';
import 'package:mitra_assistant/features/ai_engine/data/prompt_templates.dart';
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

    test('Insight JSON round-trips new categories and latency', () {
      final insight = Insight(
        id: 'u1',
        category: InsightCategory.unansweredQuestion,
        title: 'Speaker 2 asked about pricing',
        description: '"What does it cost?"',
        timestamp: DateTime(2026, 10, 19, 10),
        latencyMs: 8200,
      );
      final copy = Insight.fromJson(insight.toJson());
      expect(copy.category, InsightCategory.unansweredQuestion);
      expect(copy.latencyMs, 8200);
    });

    test('Insight.fromJson falls back for unknown category', () {
      final insight = Insight.fromJson({
        'id': 'x',
        'category': 'somethingNew',
        'title': 't',
        'description': 'd',
        'timestamp': DateTime(2026).toIso8601String(),
      });
      expect(insight.category, InsightCategory.suggestion);
      expect(insight.latencyMs, isNull);
    });

    test('analysis prompt includes earlier-meeting recall only when provided', () {
      final with_ = PromptTemplates.buildAnalysisPrompt(
        'Speaker 1: budget?',
        earlierMeetings: '- "Q3 budget" came up on 12 Oct 2026',
      );
      expect(with_, contains('Earlier meetings'));
      expect(with_, contains('Q3 budget'));
      expect(PromptTemplates.buildAnalysisPrompt('Speaker 1: budget?'), isNot(contains('Earlier meetings')));
    });
  });
}
