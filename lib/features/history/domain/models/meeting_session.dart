import '../../../ai_engine/domain/models/insight.dart';
import '../../../coaching/domain/models/coaching_feedback.dart';
import '../../../coaching/domain/models/coaching_report.dart';
import '../../../coaching/domain/models/meeting_digest.dart';
import '../../../transcription/domain/models/transcript_entry.dart';

class MeetingSession {
  final String id;
  final String title;
  final String aiSummary;
  final DateTime startTime;
  final DateTime endTime;
  final List<TranscriptEntry> entries;
  final String? exportedCsvPath;
  final CoachingReport? coachingReport;

  /// Maps a diarised label ("Speaker 1") to a real name, set by the user.
  final Map<String, String> speakerNames;

  /// Insights shown during the meeting (kept for evaluation / reports).
  final List<Insight> insights;

  /// Topics, decisions, actions and open questions (feeds the meeting graph).
  final MeetingDigest? digest;

  /// Which diarised label is the user. Set by the "This is me" pick.
  final String? meSpeakerKey;

  /// Personalised coaching for [meSpeakerKey].
  final CoachingFeedback? feedback;

  MeetingSession({
    required this.id,
    required this.title,
    required this.aiSummary,
    required this.startTime,
    required this.endTime,
    required this.entries,
    this.exportedCsvPath,
    this.coachingReport,
    this.speakerNames = const {},
    this.insights = const [],
    this.digest,
    this.meSpeakerKey,
    this.feedback,
  });

  /// Display name for a diarised label, falling back to the label itself.
  String nameFor(String speakerKey) => speakerNames[speakerKey] ?? speakerKey;

  MeetingSession copyWith({
    String? id,
    String? title,
    String? aiSummary,
    DateTime? startTime,
    DateTime? endTime,
    List<TranscriptEntry>? entries,
    String? exportedCsvPath,
    CoachingReport? coachingReport,
    Map<String, String>? speakerNames,
    List<Insight>? insights,
    MeetingDigest? digest,
    String? meSpeakerKey,
    CoachingFeedback? feedback,
  }) {
    return MeetingSession(
      id: id ?? this.id,
      title: title ?? this.title,
      aiSummary: aiSummary ?? this.aiSummary,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      entries: entries ?? this.entries,
      exportedCsvPath: exportedCsvPath ?? this.exportedCsvPath,
      coachingReport: coachingReport ?? this.coachingReport,
      speakerNames: speakerNames ?? this.speakerNames,
      insights: insights ?? this.insights,
      digest: digest ?? this.digest,
      meSpeakerKey: meSpeakerKey ?? this.meSpeakerKey,
      feedback: feedback ?? this.feedback,
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
      if (coachingReport != null) 'coachingReport': coachingReport!.toJson(),
      'speakerNames': speakerNames,
      'insights': insights.map((i) => i.toJson()).toList(),
      if (digest != null) 'digest': digest!.toJson(),
      if (meSpeakerKey != null) 'meSpeakerKey': meSpeakerKey,
      if (feedback != null) 'feedback': feedback!.toJson(),
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
      coachingReport: json['coachingReport'] is Map<String, dynamic>
          ? CoachingReport.fromJson(json['coachingReport'] as Map<String, dynamic>)
          : null,
      speakerNames: (json['speakerNames'] as Map<String, dynamic>? ?? {})
          .map((k, v) => MapEntry(k, v as String)),
      insights: (json['insights'] as List<dynamic>?)
              ?.map((i) => Insight.fromJson(i as Map<String, dynamic>))
              .toList() ??
          [],
      digest: json['digest'] is Map<String, dynamic>
          ? MeetingDigest.fromJson(json['digest'] as Map<String, dynamic>)
          : null,
      meSpeakerKey: json['meSpeakerKey'] as String?,
      feedback: json['feedback'] is Map<String, dynamic>
          ? CoachingFeedback.fromJson(json['feedback'] as Map<String, dynamic>)
          : null,
    );
  }
}
