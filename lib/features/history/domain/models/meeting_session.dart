import '../../../transcription/domain/models/transcript_entry.dart';

class MeetingSession {
  final String id;
  final String title;
  final String aiSummary;
  final DateTime startTime;
  final DateTime endTime;
  final List<TranscriptEntry> entries;
  final String? exportedCsvPath;

  MeetingSession({
    required this.id,
    required this.title,
    required this.aiSummary,
    required this.startTime,
    required this.endTime,
    required this.entries,
    this.exportedCsvPath,
  });

  MeetingSession copyWith({
    String? id,
    String? title,
    String? aiSummary,
    DateTime? startTime,
    DateTime? endTime,
    List<TranscriptEntry>? entries,
    String? exportedCsvPath,
  }) {
    return MeetingSession(
      id: id ?? this.id,
      title: title ?? this.title,
      aiSummary: aiSummary ?? this.aiSummary,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      entries: entries ?? this.entries,
      exportedCsvPath: exportedCsvPath ?? this.exportedCsvPath,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'aiSummary': aiSummary,
      'startTime': startTime.toIso8601String(),
      'endTime': endTime.toIso8601String(),
      'entries': entries.map((e) => e.toJson()).toList(),
      'exportedCsvPath': exportedCsvPath,
    };
  }

  factory MeetingSession.fromJson(Map<String, dynamic> json) {
    return MeetingSession(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? 'Untitled Meeting',
      aiSummary: json['aiSummary'] as String? ?? '',
      startTime: DateTime.parse(json['startTime'] as String),
      endTime: DateTime.parse(json['endTime'] as String),
      entries: (json['entries'] as List<dynamic>?)
              ?.map((e) => TranscriptEntry.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      exportedCsvPath: json['exportedCsvPath'] as String?,
    );
  }
}
