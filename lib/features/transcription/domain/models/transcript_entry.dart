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
}
