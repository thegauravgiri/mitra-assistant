import '../../../core/constants/app_constants.dart';
import '../../transcription/domain/models/transcript_entry.dart';
import '../domain/models/speaker_metrics.dart';

class _Turn {
  final String key;
  double? start;
  double? end;
  final StringBuffer text = StringBuffer();

  _Turn(this.key, this.start, this.end, String firstText) {
    text.write(firstText);
  }
}

/// Computes per-speaker participation from a diarised transcript.
///
/// Talk time comes from Deepgram word timings, so entries without timings
/// (e.g. sessions saved before diarisation) count towards words and turns only.
///
/// Interruptions are a heuristic: the audio is a single mixed stream, so true
/// overlapping speech is only visible when diarisation reports overlapping
/// word times. A handover with almost no gap, after a turn that didn't end in
/// terminal punctuation, is also counted.
/// Spoken fillers. "like" is only counted when comma-delimited ("it was, like,
/// huge") because the verb "I like it" is far more common.
final RegExp _fillerPattern = RegExp(
  r"\b(um+|uh+|uhm|erm?|you know|i mean|sort of|kind of|basically)\b|,\s*like\s*,",
  caseSensitive: false,
);

class ParticipationAnalyzer {
  /// Filler counts by (lower-cased) phrase for one piece of text.
  static Map<String, int> countFillers(String text) {
    final counts = <String, int>{};
    for (final m in _fillerPattern.allMatches(text)) {
      final key = (m.group(1) ?? 'like').toLowerCase();
      counts[key] = (counts[key] ?? 0) + 1;
    }
    return counts;
  }

  static List<SpeakerMetrics> analyze(
    List<TranscriptEntry> entries, {
    double turnMergeGapSec = AppConstants.turnMergeGapSec,
    double interruptGapSec = AppConstants.interruptGapSec,
  }) {
    final finals = entries.where((e) => e.isFinal).toList();
    if (finals.isEmpty) return const [];

    final talk = <String, double>{};
    final words = <String, int>{};
    final turnCounts = <String, int>{};
    final made = <String, int>{};
    final received = <String, int>{};
    final order = <String>[];
    final fillers = <String, Map<String, int>>{};
    final questions = <String, int>{};

    void touch(String k) {
      if (!talk.containsKey(k)) {
        order.add(k);
        talk[k] = 0;
        words[k] = 0;
        turnCounts[k] = 0;
        made[k] = 0;
        received[k] = 0;
        fillers[k] = {};
        questions[k] = 0;
      }
    }

    final turns = <_Turn>[];
    for (final e in finals) {
      final k = e.speaker;
      touch(k);
      words[k] = words[k]! + _wordCount(e.text);
      countFillers(e.text).forEach((f, n) {
        fillers[k]![f] = (fillers[k]![f] ?? 0) + n;
      });
      questions[k] = questions[k]! + '?'.allMatches(e.text).length;
      final timed = e.startSec != null && e.endSec != null;
      if (timed) talk[k] = talk[k]! + (e.endSec! - e.startSec!).clamp(0, 1e9);

      final last = turns.isEmpty ? null : turns.last;
      final sameTurn = last != null &&
          last.key == k &&
          (!timed ||
              last.end == null ||
              (e.startSec! - last.end!) <= turnMergeGapSec);
      if (sameTurn) {
        last.text.write(' ${e.text}');
        if (timed) {
          last.start ??= e.startSec;
          last.end = e.endSec;
        }
      } else {
        turns.add(_Turn(k, e.startSec, e.endSec, e.text));
        turnCounts[k] = turnCounts[k]! + 1;
      }
    }

    for (var i = 1; i < turns.length; i++) {
      final a = turns[i - 1];
      final b = turns[i];
      if (a.key == b.key || a.end == null || b.start == null) continue;
      final gap = b.start! - a.end!;
      final overlap = gap < 0;
      final cutOff = gap >= 0 &&
          gap < interruptGapSec &&
          !_endsSentence(a.text.toString());
      if (overlap || cutOff) {
        made[b.key] = made[b.key]! + 1;
        received[a.key] = received[a.key]! + 1;
      }
    }

    // Turn-level delivery measures.
    final longest = <String, double>{};
    final turnTime = <String, double>{};
    final timedTurns = <String, int>{};
    for (final t in turns) {
      if (t.start == null || t.end == null) continue;
      final d = (t.end! - t.start!).clamp(0, 1e9).toDouble();
      timedTurns[t.key] = (timedTurns[t.key] ?? 0) + 1;
      turnTime[t.key] = (turnTime[t.key] ?? 0) + d;
      if (d > (longest[t.key] ?? 0)) longest[t.key] = d;
    }
    final gapSum = <String, double>{};
    final gapCount = <String, int>{};
    for (var i = 1; i < turns.length; i++) {
      final a = turns[i - 1];
      final b = turns[i];
      if (a.key == b.key || a.end == null || b.start == null) continue;
      final gap = (b.start! - a.end!).clamp(0, 1e9).toDouble();
      gapSum[b.key] = (gapSum[b.key] ?? 0) + gap;
      gapCount[b.key] = (gapCount[b.key] ?? 0) + 1;
    }

    final totalTime = talk.values.fold<double>(0, (s, v) => s + v);
    final totalWords = words.values.fold<int>(0, (s, v) => s + v);

    return [
      for (final k in order)
        () {
          final talkSec = talk[k]!;
          final enoughTalk = talkSec >= AppConstants.minTalkSecForRates;
          final fillerTotal = fillers[k]!.values.fold<int>(0, (a, b) => a + b);
          return SpeakerMetrics(
            speakerKey: k,
            talkTimeSec: talkSec,
            talkSharePct: totalTime > 0
                ? talkSec / totalTime * 100
                : (totalWords > 0 ? words[k]! / totalWords * 100 : 0),
            turnCount: turnCounts[k]!,
            wordCount: words[k]!,
            interruptionsMade: made[k]!,
            interruptionsReceived: received[k]!,
            paceWpm: enoughTalk ? words[k]! / (talkSec / 60) : null,
            fillerCount: fillerTotal,
            fillersPerMin: enoughTalk ? fillerTotal / (talkSec / 60) : null,
            fillerBreakdown: fillers[k]!,
            longestMonologueSec: longest[k],
            avgTurnSec: timedTurns[k] == null ? null : turnTime[k]! / timedTurns[k]!,
            questionsAsked: questions[k]!,
            avgResponseGapSec:
                gapCount[k] == null ? null : gapSum[k]! / gapCount[k]!,
          );
        }(),
    ];
  }

  static int _wordCount(String t) =>
      t.trim().isEmpty ? 0 : t.trim().split(RegExp(r'\s+')).length;

  static bool _endsSentence(String t) {
    final s = t.trimRight();
    return s.endsWith('.') || s.endsWith('?') || s.endsWith('!');
  }
}
