class TranscriptEntry {
  final String id;
  final String text;
  final DateTime timestamp;
  final bool isFinal;
  final String speaker; // e.g. "Speaker 1", "You"

  TranscriptEntry({
    required this.id,
    required this.text,
    required this.timestamp,
    required this.isFinal,
    this.speaker = 'Meeting Participant',
  });

  TranscriptEntry copyWith({
    String? id,
    String? text,
    DateTime? timestamp,
    bool? isFinal,
    String? speaker,
  }) {
    return TranscriptEntry(
      id: id ?? this.id,
      text: text ?? this.text,
      timestamp: timestamp ?? this.timestamp,
      isFinal: isFinal ?? this.isFinal,
      speaker: speaker ?? this.speaker,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'text': text,
      'timestamp': timestamp.toIso8601String(),
      'isFinal': isFinal,
      'speaker': speaker,
    };
  }

  factory TranscriptEntry.fromJson(Map<String, dynamic> json) {
    return TranscriptEntry(
      id: json['id'] as String? ?? '',
      text: json['text'] as String? ?? '',
      timestamp: DateTime.parse(json['timestamp'] as String),
      isFinal: json['isFinal'] as bool? ?? true,
      speaker: json['speaker'] as String? ?? 'Meeting Participant',
    );
  }
}
