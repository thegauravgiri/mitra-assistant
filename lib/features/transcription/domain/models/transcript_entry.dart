class TranscriptEntry {
  final String id;
  final String text;
  final DateTime timestamp;
  final bool isFinal;
  final String speaker; // e.g. "Speaker 1", "You"
  final int? speakerIndex; // raw Deepgram diarisation index (null if unknown)
  final double? startSec; // offset from session start, from word timings
  final double? endSec;

  TranscriptEntry({
    required this.id,
    required this.text,
    required this.timestamp,
    required this.isFinal,
    this.speaker = 'Meeting Participant',
    this.speakerIndex,
    this.startSec,
    this.endSec,
  });

  TranscriptEntry copyWith({
    String? id,
    String? text,
    DateTime? timestamp,
    bool? isFinal,
    String? speaker,
    int? speakerIndex,
    double? startSec,
    double? endSec,
  }) {
    return TranscriptEntry(
      id: id ?? this.id,
      text: text ?? this.text,
      timestamp: timestamp ?? this.timestamp,
      isFinal: isFinal ?? this.isFinal,
      speaker: speaker ?? this.speaker,
      speakerIndex: speakerIndex ?? this.speakerIndex,
      startSec: startSec ?? this.startSec,
      endSec: endSec ?? this.endSec,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'text': text,
      'timestamp': timestamp.toIso8601String(),
      'isFinal': isFinal,
      'speaker': speaker,
      if (speakerIndex != null) 'speakerIndex': speakerIndex,
      if (startSec != null) 'startSec': startSec,
      if (endSec != null) 'endSec': endSec,
    };
  }

  factory TranscriptEntry.fromJson(Map<String, dynamic> json) {
    return TranscriptEntry(
      id: json['id'] as String? ?? '',
      text: json['text'] as String? ?? '',
      timestamp: DateTime.parse(json['timestamp'] as String),
      isFinal: json['isFinal'] as bool? ?? true,
      speaker: json['speaker'] as String? ?? 'Meeting Participant',
      speakerIndex: (json['speakerIndex'] as num?)?.toInt(),
      startSec: (json['startSec'] as num?)?.toDouble(),
      endSec: (json['endSec'] as num?)?.toDouble(),
    );
  }
}
