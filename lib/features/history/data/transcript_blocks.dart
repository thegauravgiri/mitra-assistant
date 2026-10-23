import '../../transcription/domain/models/transcript_entry.dart';

/// Consecutive lines from one speaker, shown as one paragraph.
class TranscriptBlock {
  final String speakerKey;
  final int? speakerIndex;
  final DateTime time; // when the block started
  final String text;

  const TranscriptBlock(this.speakerKey, this.speakerIndex, this.time, this.text);
}

class TranscriptBlocks {
  /// Merges consecutive same-speaker final lines into blocks. A pause of more
  /// than [splitGapSec] (when timings exist) starts a new block even for the
  /// same speaker, so long monologues stay readable.
  static List<TranscriptBlock> from(List<TranscriptEntry> entries, {double splitGapSec = 20}) {
    final blocks = <TranscriptBlock>[];
    TranscriptEntry? last;
    for (final e in entries.where((e) => e.isFinal)) {
      final gap = last?.endSec != null && e.startSec != null ? e.startSec! - last!.endSec! : 0.0;
      if (blocks.isNotEmpty && blocks.last.speakerKey == e.speaker && gap <= splitGapSec) {
        final b = blocks.removeLast();
        blocks.add(TranscriptBlock(b.speakerKey, b.speakerIndex, b.time, '${b.text} ${e.text}'));
      } else {
        blocks.add(TranscriptBlock(e.speaker, e.speakerIndex, e.timestamp, e.text));
      }
      last = e;
    }
    return blocks;
  }

  /// Blocks whose text contains [query] (case-insensitive). Empty query = all.
  static List<TranscriptBlock> search(List<TranscriptBlock> blocks, String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return blocks;
    return [for (final b in blocks) if (b.text.toLowerCase().contains(q)) b];
  }
}
