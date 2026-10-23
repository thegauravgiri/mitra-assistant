class SpeakerMetrics {
  final String speakerKey; // matches TranscriptEntry.speaker, e.g. "Speaker 1"
  final double talkTimeSec;
  final double talkSharePct;
  final int turnCount;
  final int wordCount;
  final int interruptionsMade;
  final int interruptionsReceived;

  // Added with the coaching overhaul. Null = not measurable (e.g. a session
  // saved before word timings existed), never a fake zero.
  final double? paceWpm;
  final int fillerCount;
  final double? fillersPerMin;
  final Map<String, int> fillerBreakdown;
  final double? longestMonologueSec;
  final double? avgTurnSec;
  final int questionsAsked;
  final double? avgResponseGapSec;

  const SpeakerMetrics({
    required this.speakerKey,
    required this.talkTimeSec,
    required this.talkSharePct,
    required this.turnCount,
    required this.wordCount,
    required this.interruptionsMade,
    required this.interruptionsReceived,
    this.paceWpm,
    this.fillerCount = 0,
    this.fillersPerMin,
    this.fillerBreakdown = const {},
    this.longestMonologueSec,
    this.avgTurnSec,
    this.questionsAsked = 0,
    this.avgResponseGapSec,
  });

  Map<String, dynamic> toJson() => {
        'speakerKey': speakerKey,
        'talkTimeSec': talkTimeSec,
        'talkSharePct': talkSharePct,
        'turnCount': turnCount,
        'wordCount': wordCount,
        'interruptionsMade': interruptionsMade,
        'interruptionsReceived': interruptionsReceived,
        if (paceWpm != null) 'paceWpm': paceWpm,
        'fillerCount': fillerCount,
        if (fillersPerMin != null) 'fillersPerMin': fillersPerMin,
        if (fillerBreakdown.isNotEmpty) 'fillerBreakdown': fillerBreakdown,
        if (longestMonologueSec != null) 'longestMonologueSec': longestMonologueSec,
        if (avgTurnSec != null) 'avgTurnSec': avgTurnSec,
        'questionsAsked': questionsAsked,
        if (avgResponseGapSec != null) 'avgResponseGapSec': avgResponseGapSec,
      };

  factory SpeakerMetrics.fromJson(Map<String, dynamic> json) => SpeakerMetrics(
        speakerKey: json['speakerKey'] as String? ?? '',
        talkTimeSec: (json['talkTimeSec'] as num?)?.toDouble() ?? 0,
        talkSharePct: (json['talkSharePct'] as num?)?.toDouble() ?? 0,
        turnCount: (json['turnCount'] as num?)?.toInt() ?? 0,
        wordCount: (json['wordCount'] as num?)?.toInt() ?? 0,
        interruptionsMade: (json['interruptionsMade'] as num?)?.toInt() ?? 0,
        interruptionsReceived: (json['interruptionsReceived'] as num?)?.toInt() ?? 0,
        paceWpm: (json['paceWpm'] as num?)?.toDouble(),
        fillerCount: (json['fillerCount'] as num?)?.toInt() ?? 0,
        fillersPerMin: (json['fillersPerMin'] as num?)?.toDouble(),
        fillerBreakdown: (json['fillerBreakdown'] as Map<String, dynamic>? ?? {})
            .map((k, v) => MapEntry(k, (v as num).toInt())),
        longestMonologueSec: (json['longestMonologueSec'] as num?)?.toDouble(),
        avgTurnSec: (json['avgTurnSec'] as num?)?.toDouble(),
        questionsAsked: (json['questionsAsked'] as num?)?.toInt() ?? 0,
        avgResponseGapSec: (json['avgResponseGapSec'] as num?)?.toDouble(),
      );
}
