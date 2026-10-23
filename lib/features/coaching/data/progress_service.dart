import '../../history/domain/models/meeting_session.dart';
import '../domain/models/speaker_metrics.dart';
import 'session_metrics.dart';

class ProgressPoint {
  final MeetingSession session;
  final SpeakerMetrics metrics;

  const ProgressPoint(this.session, this.metrics);
}

/// Pure helpers for comparing one person's participation across meetings.
/// People are identified by the name the user typed for a diarised label.
class ProgressService {
  static String _norm(String s) => s.trim().toLowerCase();

  /// Distinct names (original casing of the first use) across all sessions.
  static List<String> knownNames(List<MeetingSession> sessions) {
    final seen = <String, String>{};
    for (final s in sessions) {
      for (final n in s.speakerNames.values) {
        if (n.trim().isNotEmpty) seen.putIfAbsent(_norm(n), () => n.trim());
      }
    }
    final names = seen.values.toList()..sort((a, b) => a.compareTo(b));
    return names;
  }

  /// Oldest-first metrics for [name]. A session where the name isn't mapped to
  /// a speaker contributes nothing.
  static List<ProgressPoint> forPerson(
    List<MeetingSession> sessions,
    String name,
  ) {
    final target = _norm(name);
    final points = <ProgressPoint>[];
    for (final s in sessions) {
      final metrics = metricsOf(s);
      for (final entry in s.speakerNames.entries) {
        if (_norm(entry.value) != target) continue;
        for (final m in metrics) {
          if (m.speakerKey == entry.key) points.add(ProgressPoint(s, m));
        }
      }
    }
    points.sort((a, b) => a.session.startTime.compareTo(b.session.startTime));
    return points;
  }
}
