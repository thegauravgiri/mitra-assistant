import '../../history/domain/models/meeting_session.dart';
import '../domain/models/speaker_metrics.dart';
import 'participation_analyzer.dart';

/// Speaker metrics for a saved meeting. Uses the stored report when there is
/// one; meetings saved before reports existed are analysed from their
/// transcript on the fly, so they can be coached and tracked too.
List<SpeakerMetrics> metricsOf(MeetingSession session) {
  final stored = session.coachingReport?.metrics;
  if (stored != null && stored.isNotEmpty) return stored;
  return ParticipationAnalyzer.analyze(session.entries);
}

/// Chip label for a speaker. Older recordings have one placeholder speaker
/// ("Meeting Participant"); say what that means instead of showing the code name.
String speakerChipLabel(MeetingSession session, SpeakerMetrics m) {
  final name = session.speakerNames[m.speakerKey];
  final base = name ??
      (m.speakerKey == 'Meeting Participant' ? 'The only speaker (older recording)' : m.speakerKey);
  return '$base · ${m.talkSharePct.toStringAsFixed(0)}%';
}
