import 'package:uuid/uuid.dart';
import '../domain/models/transcript_entry.dart';

/// Turns a decoded Deepgram `Results` message into a [TranscriptEntry].
///
/// Pure (no I/O) so it can be unit-tested. Speaker is the majority
/// `word.speaker` among the words; timings come from the first/last word.
class DeepgramMessageParser {
  static const _uuid = Uuid();

  /// Who a word belongs to.
  ///
  /// Two-channel audio (multichannel): channel 0 is the microphone, i.e. the
  /// user, always "You"; channel 1 is the call, where Deepgram's diarisation
  /// numbers the people on that channel (restarting at 0), shown as Speaker 2,
  /// 3, ... Single-channel audio keeps the plain diarised numbering.
  static ({String label, int? index}) labelFor(int channel, int totalChannels, int? diarised) {
    if (totalChannels > 1) {
      if (channel == 0) return (label: youLabel, index: 0);
      final s = diarised ?? 0;
      return (label: 'Speaker ${s + 2}', index: s + 1);
    }
    return diarised == null
        ? (label: 'Meeting Participant', index: null)
        : (label: 'Speaker ${diarised + 1}', index: diarised);
  }

  static const String youLabel = 'You';

  /// (channel index, total channels) of a result; (0, 1) when single-channel.
  static (int, int) channelOf(Map<String, dynamic> json) {
    final ci = json['channel_index'];
    if (ci is List && ci.length >= 2) {
      return ((ci[0] as num).toInt(), (ci[1] as num).toInt());
    }
    return (0, 1);
  }

  /// A lone word shorter than this between two runs of the same speaker is
  /// treated as diarisation flicker; a real one-word reply ("Yes.") lasts longer.
  static const double maxFlickerSeconds = 0.35;

  static double _wordSeconds(Map<String, dynamic> w) {
    final s = (w['start'] as num?)?.toDouble();
    final e = (w['end'] as num?)?.toDouble();
    return s == null || e == null ? double.infinity : e - s;
  }

  /// A final result can contain several people (a quick reply, an interjection).
  /// Returns one entry per run of consecutive words by the same speaker, so each
  /// voice gets its own line. Interim results stay a single entry (they are only
  /// shown live). A very short lone word between two runs of the same speaker is
  /// treated as diarisation flicker and absorbed.
  static List<TranscriptEntry> parseAll(
    Map<String, dynamic> json, {
    double timeOffsetSec = 0,
    DateTime? now,
  }) {
    final single = parse(json, timeOffsetSec: timeOffsetSec, now: now);
    if (single == null) return const [];
    if (!single.isFinal) return [single];
    final (channel, total) = channelOf(json);
    if (total > 1 && channel == 0) return [single]; // the microphone is one person

    final alt = ((json['channel'] as Map<String, dynamic>)['alternatives'] as List<dynamic>).first as Map<String, dynamic>;
    final words = (alt['words'] as List<dynamic>?)?.whereType<Map<String, dynamic>>().toList() ?? const [];
    if (words.isEmpty || words.every((w) => w['speaker'] == null)) return [single];

    // speaker per word; a word with no label inherits the previous one
    final speakers = <int?>[];
    int? previous;
    for (final w in words) {
      final sp = (w['speaker'] as num?)?.toInt() ?? previous;
      speakers.add(sp);
      previous = sp;
    }

    // runs of equal speaker as [start, end) word ranges
    var runs = <({int from, int to, int? speaker})>[];
    var from = 0;
    for (var i = 1; i <= words.length; i++) {
      if (i == words.length || speakers[i] != speakers[from]) {
        runs.add((from: from, to: i, speaker: speakers[from]));
        from = i;
      }
    }

    // absorb single-word flicker: A [B] A -> A A A
    var changed = true;
    while (changed && runs.length >= 3) {
      changed = false;
      for (var i = 1; i < runs.length - 1; i++) {
        final r = runs[i];
        final oneShortWord = r.to - r.from == 1 && _wordSeconds(words[r.from]) < maxFlickerSeconds;
        if (oneShortWord && runs[i - 1].speaker == runs[i + 1].speaker) {
          runs = [
            ...runs.sublist(0, i - 1),
            (from: runs[i - 1].from, to: runs[i + 1].to, speaker: runs[i - 1].speaker),
            ...runs.sublist(i + 2),
          ];
          changed = true;
          break;
        }
      }
    }
    if (runs.length == 1) return [single];

    return [
      for (final r in runs)
        _entryFor(words.sublist(r.from, r.to), r.speaker, channel, total, timeOffsetSec, now),
    ];
  }

  static TranscriptEntry _entryFor(
    List<Map<String, dynamic>> run,
    int? speaker,
    int channel,
    int total,
    double offset,
    DateTime? now,
  ) {
    final text = run
        .map((w) => (w['punctuated_word'] ?? w['word'] ?? '').toString())
        .where((t) => t.isNotEmpty)
        .join(' ');
    final s = (run.first['start'] as num?)?.toDouble();
    final e = (run.last['end'] as num?)?.toDouble();
    final who = labelFor(channel, total, speaker);
    return TranscriptEntry(
      id: _uuid.v4(),
      text: text,
      timestamp: now ?? DateTime.now(),
      isFinal: true,
      speaker: who.label,
      speakerIndex: who.index,
      startSec: s == null ? null : s + offset,
      endSec: e == null ? null : e + offset,
    );
  }

  /// [timeOffsetSec] is added to word timings so they keep increasing across
  /// reconnects (Deepgram restarts timestamps at 0 on each connection).
  static TranscriptEntry? parse(
    Map<String, dynamic> json, {
    double timeOffsetSec = 0,
    DateTime? now,
  }) {
    final channel = json['channel'] as Map<String, dynamic>?;
    if (channel == null) return null;

    final alternatives = channel['alternatives'] as List<dynamic>?;
    if (alternatives == null || alternatives.isEmpty) return null;

    final alt = alternatives[0] as Map<String, dynamic>;
    final text = alt['transcript'] as String? ?? '';
    if (text.trim().isEmpty) return null;

    final words = (alt['words'] as List<dynamic>?)
            ?.whereType<Map<String, dynamic>>()
            .toList() ??
        const <Map<String, dynamic>>[];

    int? speakerIndex;
    double? start;
    double? end;

    if (words.isNotEmpty) {
      final counts = <int, int>{};
      for (final w in words) {
        final s = (w['speaker'] as num?)?.toInt();
        if (s != null) counts[s] = (counts[s] ?? 0) + 1;
      }
      if (counts.isNotEmpty) {
        speakerIndex = counts.entries
            .reduce((a, b) => b.value > a.value ? b : a)
            .key;
      }
      final s = (words.first['start'] as num?)?.toDouble();
      final e = (words.last['end'] as num?)?.toDouble();
      if (s != null) start = s + timeOffsetSec;
      if (e != null) end = e + timeOffsetSec;
    }

    final (channelIdx, channelTotal) = channelOf(json);
    final who = labelFor(channelIdx, channelTotal, speakerIndex);
    return TranscriptEntry(
      id: _uuid.v4(),
      text: text,
      timestamp: now ?? DateTime.now(),
      isFinal: json['is_final'] as bool? ?? false,
      speaker: who.label,
      speakerIndex: who.index,
      startSec: start,
      endSec: end,
    );
  }
}
