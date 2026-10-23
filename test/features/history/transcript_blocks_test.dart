import 'package:flutter_test/flutter_test.dart';
import 'package:mitra_assistant/features/history/data/transcript_blocks.dart';
import 'package:mitra_assistant/features/transcription/domain/models/transcript_entry.dart';

TranscriptEntry e(String sp, String text, {double? s, double? en, bool fin = true}) => TranscriptEntry(
      id: '$sp$text',
      text: text,
      timestamp: DateTime(2026, 10, 19, 10),
      isFinal: fin,
      speaker: sp,
      startSec: s,
      endSec: en,
    );

void main() {
  test('merges consecutive same-speaker lines and splits on speaker change', () {
    final b = TranscriptBlocks.from([e('A', 'one.'), e('A', 'two.'), e('B', 'three.'), e('A', 'four.')]);
    expect(b.map((x) => '${x.speakerKey}:${x.text}'), ['A:one. two.', 'B:three.', 'A:four.']);
  });

  test('a long pause starts a new block for the same speaker', () {
    final b = TranscriptBlocks.from([e('A', 'one.', s: 0, en: 5), e('A', 'two.', s: 40, en: 45)]);
    expect(b.length, 2);
    final close = TranscriptBlocks.from([e('A', 'one.', s: 0, en: 5), e('A', 'two.', s: 8, en: 12)]);
    expect(close.length, 1);
  });

  test('ignores interim lines; empty input gives no blocks', () {
    expect(TranscriptBlocks.from([e('A', 'draft', fin: false)]), isEmpty);
    expect(TranscriptBlocks.from([]), isEmpty);
  });

  test('search is case-insensitive and an empty query returns everything', () {
    final b = TranscriptBlocks.from([e('A', 'Ship on Friday'), e('B', 'Budget first')]);
    expect(TranscriptBlocks.search(b, 'friday').single.speakerKey, 'A');
    expect(TranscriptBlocks.search(b, '  ').length, 2);
    expect(TranscriptBlocks.search(b, 'nothing'), isEmpty);
  });
}
