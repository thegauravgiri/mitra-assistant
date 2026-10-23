import 'package:flutter_test/flutter_test.dart';
import 'package:mitra_assistant/features/ai_engine/data/prompt_templates.dart';
import 'package:mitra_assistant/features/ai_engine/data/transcript_window.dart';

void main() {
  group('live analysis prompt', () {
    test('includes the running notes, earlier meetings and documents only when given', () {
      final full = PromptTemplates.buildAnalysisPrompt(
        'You: what is the budget?',
        meetingSoFar: 'Topics: pricing.',
        earlierMeetings: '- "Q3 budget" came up on 12 Oct',
        documentContext: '=== Document: pricing.pdf ===',
      );
      expect(full, contains('Meeting so far'));
      expect(full, contains('Topics: pricing.'));
      expect(full, contains('Earlier meetings'));
      expect(full, contains('Reference Documents'));

      final bare = PromptTemplates.buildAnalysisPrompt('You: hi');
      expect(bare, isNot(contains('Meeting so far')));
      expect(bare, isNot(contains('Earlier meetings')));
      expect(bare, isNot(contains('Reference Documents')));
    });

    test('the system prompt sets a real quality bar and knows "You"', () {
      final s = PromptTemplates.systemPrompt;
      for (final cat in ['suggestion', 'keyPoint', 'question', 'actionItem', 'answer', 'unansweredQuestion']) {
        expect(s, contains('"$cat"'));
      }
      expect(s, contains('"You"'));
      expect(s, contains('at most 3'));
      expect(s, contains('contradiction'));
    });

    test('already-suggested titles are listed so they are not repeated', () {
      final p = PromptTemplates.buildAnalysisPrompt('x', existingInsights: ['Ask about pricing']);
      expect(p, contains('- Ask about pricing'));
    });
  });

  test('the Ask box prompt carries the notes, earlier meetings, documents and the question', () {
    final p = PromptTemplates.buildQuestionPrompt(
      'Speaker 2: we are late',
      'What did we decide last time?',
      meetingSoFar: 'Decisions: freeze hiring',
      earlierMeetings: '- decided: hold hiring',
      documentContext: 'doc text',
    );
    expect(p, contains('Meeting so far (running notes)'));
    expect(p, contains('Earlier meetings'));
    expect(p, contains('Reference documents'));
    expect(p, contains('What did we decide last time?'));
    expect(p, contains('never guess'));
  });

  test('document summary prompt asks for specifics, not two sentences', () {
    expect(PromptTemplates.documentSummarySystemPrompt, contains('6-10 sentences'));
    expect(PromptTemplates.documentSummarySystemPrompt, contains('figures'));
  });

  test('digest prompts demand descriptive, verifiable notes and handle long meetings in parts', () {
    final d = PromptTemplates.digestSystemPrompt;
    expect(d, contains('5-9 sentences'));
    expect(d, contains('verbatim'));
    expect(d, contains('Never invent'));
    expect(PromptTemplates.digestSegmentSystemPrompt, contains('ONE PART'));
    expect(PromptTemplates.digestMergeSystemPrompt, contains('CONSECUTIVE PARTS'));
    expect(PromptTemplates.digestMergeSystemPrompt, contains('answers is NOT open'));
    expect(PromptTemplates.buildDigestMergePrompt(['{"a":1}', '{"b":2}']), contains('Part 2 notes:'));
  });

  group('TranscriptWindow', () {
    final text = List.generate(100, (i) => 'Speaker: line number $i').join('\n');

    test('short text is returned whole; long text starts on a line boundary', () {
      expect(TranscriptWindow.recent('short', 100), 'short');
      final r = TranscriptWindow.recent(text, 300);
      expect(r.length, lessThanOrEqualTo(300));
      expect(r.startsWith('Speaker:'), isTrue); // not cut mid-line
      expect(text.endsWith(r), isTrue);
    });

    test('summarise only after enough text has left the window', () {
      expect(TranscriptWindow.shouldSummarise(text, max: 300, summarisedUpTo: 0, chunk: 1000), isTrue);
      expect(TranscriptWindow.shouldSummarise(text, max: 300, summarisedUpTo: 0, chunk: 99999), isFalse);
      final start = TranscriptWindow.recentStart(text, 300);
      expect(TranscriptWindow.shouldSummarise(text, max: 300, summarisedUpTo: start, chunk: 1), isFalse);
      expect(TranscriptWindow.shouldSummarise('short', max: 300, summarisedUpTo: 0, chunk: 1), isFalse);
    });
  });
}
