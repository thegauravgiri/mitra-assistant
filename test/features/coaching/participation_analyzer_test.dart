import 'package:flutter_test/flutter_test.dart';
import 'package:mitra_assistant/features/coaching/data/participation_analyzer.dart';
import 'package:mitra_assistant/features/transcription/domain/models/transcript_entry.dart';

TranscriptEntry e(String speaker, String text, [double? s, double? en]) =>
    TranscriptEntry(
      id: '${speaker}_$text',
      text: text,
      timestamp: DateTime(2026),
      isFinal: true,
      speaker: speaker,
      startSec: s,
      endSec: en,
    );

void main() {
  group('ParticipationAnalyzer', () {
    test('empty input gives no metrics', () {
      expect(ParticipationAnalyzer.analyze([]), isEmpty);
    });

    test('talk time, share and words', () {
      final m = ParticipationAnalyzer.analyze([
        e('Speaker 1', 'Hello team. Welcome.', 0, 6),
        e('Speaker 2', 'Thanks for having me.', 6.5, 8.5),
      ]);
      expect(m.length, 2);
      expect(m[0].talkTimeSec, 6);
      expect(m[1].talkTimeSec, 2);
      expect(m[0].talkSharePct, closeTo(75, 0.01));
      expect(m.fold<double>(0, (s, x) => s + x.talkSharePct), closeTo(100, 0.01));
      expect(m[0].wordCount, 3);
    });

    test('merges same-speaker lines within the gap into one turn', () {
      final m = ParticipationAnalyzer.analyze([
        e('Speaker 1', 'First part.', 0, 2),
        e('Speaker 1', 'Second part.', 2.5, 4), // 0.5s gap -> same turn
        e('Speaker 2', 'Reply.', 6, 7),
        e('Speaker 1', 'Later.', 9, 10), // new turn
      ]);
      expect(m[0].turnCount, 2);
      expect(m[1].turnCount, 1);
    });

    test('counts overlap as an interruption', () {
      final m = ParticipationAnalyzer.analyze([
        e('Speaker 1', 'So what I wanted to say is', 0, 5),
        e('Speaker 2', 'Sorry, quick question.', 4.2, 6),
      ]);
      expect(m[1].interruptionsMade, 1);
      expect(m[0].interruptionsReceived, 1);
    });

    test('counts near-zero gap after unfinished sentence, not after a finished one', () {
      final cut = ParticipationAnalyzer.analyze([
        e('Speaker 1', 'and then we should', 0, 3),
        e('Speaker 2', 'Right.', 3.1, 4),
      ]);
      expect(cut[1].interruptionsMade, 1);

      final clean = ParticipationAnalyzer.analyze([
        e('Speaker 1', 'That is all.', 0, 3),
        e('Speaker 2', 'Right.', 3.1, 4),
      ]);
      expect(clean[1].interruptionsMade, 0);
    });

    test('entries without timings count words and turns but not time', () {
      final m = ParticipationAnalyzer.analyze([
        e('Speaker 1', 'one two three'),
        e('Speaker 2', 'four five'),
      ]);
      expect(m[0].talkTimeSec, 0);
      expect(m[0].wordCount, 3);
      expect(m[0].talkSharePct, closeTo(60, 0.01)); // falls back to word share
    });
  });
}
