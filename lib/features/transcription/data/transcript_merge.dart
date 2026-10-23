import '../../../core/utils/text_similarity.dart';
import '../domain/models/transcript_entry.dart';

/// Rules for adding a finished line to the running transcript when the mic and
/// the call arrive on separate channels.
class TranscriptMerge {
  static const String me = 'You';
  static const double echoWindowSec = 4;
  static const int minEchoTokens = 3;
  static const double echoOverlap = 0.75;
  static const int recentLines = 8;

  /// Is [a] (from the microphone) the same words as [b] (from the call), spoken
  /// at about the same time? That is the call leaking out of the speakers into
  /// the mic: the same sentence appears on both channels.
  static bool isEcho(TranscriptEntry a, TranscriptEntry b) {
    final ta = TextSimilarity.tokenize(a.text);
    final tb = TextSimilarity.tokenize(b.text);
    if (ta.length < minEchoTokens || tb.length < minEchoTokens) return false;

    final dt = a.startSec != null && b.startSec != null
        ? (a.startSec! - b.startSec!).abs()
        : a.timestamp.difference(b.timestamp).inMilliseconds.abs() / 1000;
    if (dt > echoWindowSec) return false;

    final shared = ta.intersection(tb).length;
    final smaller = ta.length < tb.length ? ta.length : tb.length;
    return shared / smaller >= echoOverlap;
  }

  /// Adds [entry] to [entries] (a new list is returned):
  /// - a "You" line that echoes a recent call line is dropped;
  /// - a call line removes recent "You" lines that were its echo;
  /// - the line goes in start-time order, since two channels arrive interleaved.
  static List<TranscriptEntry> add(List<TranscriptEntry> entries, TranscriptEntry entry) {
    final recent = entries.length > recentLines ? entries.sublist(entries.length - recentLines) : entries;

    if (entry.speaker == me) {
      if (recent.any((e) => e.speaker != me && isEcho(entry, e))) return entries;
    }

    var list = [...entries];
    if (entry.speaker != me) {
      final echoes = {
        for (final e in recent)
          if (e.speaker == me && isEcho(e, entry)) e.id,
      };
      if (echoes.isNotEmpty) list = [for (final e in list) if (!echoes.contains(e.id)) e];
    }

    var i = list.length;
    while (i > 0 && _startsAfter(list[i - 1], entry)) {
      i--;
    }
    list.insert(i, entry);
    return list;
  }

  static bool _startsAfter(TranscriptEntry a, TranscriptEntry b) =>
      a.startSec != null && b.startSec != null && a.startSec! > b.startSec!;
}
