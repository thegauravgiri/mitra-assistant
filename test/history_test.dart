import 'package:flutter_test/flutter_test.dart';
import 'package:mitra_assistant/features/coaching/domain/models/coaching_report.dart';
import 'package:mitra_assistant/features/coaching/domain/models/speaker_metrics.dart';
import 'package:mitra_assistant/features/history/domain/models/meeting_session.dart';
import 'package:mitra_assistant/features/transcription/domain/models/transcript_entry.dart';

void main() {
  group('MeetingSession Serialization', () {
    test('toJson and fromJson work correctly', () {
      final now = DateTime.now();
      final entry = TranscriptEntry(
        id: 'entry-1',
        text: 'Hello world',
        timestamp: now,
        isFinal: true,
        speaker: 'Meeting Participant',
      );

      final session = MeetingSession(
        id: 'session-1',
        title: 'Project Kickoff',
        aiSummary: 'Short 1-2 line summary',
        startTime: now,
        endTime: now.add(const Duration(minutes: 30)),
        entries: [entry],
        exportedCsvPath: '/tmp/test_meeting.csv',
      );

      final json = session.toJson();
      final restored = MeetingSession.fromJson(json);

      expect(restored.id, equals(session.id));
      expect(restored.title, equals(session.title));
      expect(restored.aiSummary, equals(session.aiSummary));
      expect(restored.exportedCsvPath, equals('/tmp/test_meeting.csv'));
      expect(restored.entries.length, equals(1));
      expect(restored.entries.first.text, equals('Hello world'));
    });

    test('old-format JSON (no coaching fields) still loads', () {
      final session = MeetingSession.fromJson({
        'id': 's',
        'title': 'Old',
        'aiSummary': '',
        'startTime': DateTime(2026, 8, 1).toIso8601String(),
        'endTime': DateTime(2026, 8, 1, 1).toIso8601String(),
        'entries': [
          {'id': 'e', 'text': 'hi', 'timestamp': DateTime(2026, 8, 1).toIso8601String()},
        ],
      });
      expect(session.coachingReport, isNull);
      expect(session.speakerNames, isEmpty);
      expect(session.insights, isEmpty);
      expect(session.entries.first.startSec, isNull);
      expect(session.nameFor('Speaker 1'), 'Speaker 1');
    });

    test('coaching report, names and timings round-trip', () {
      final session = MeetingSession(
        id: 's',
        title: 'T',
        aiSummary: '',
        startTime: DateTime(2026),
        endTime: DateTime(2026),
        entries: [
          TranscriptEntry(
            id: 'e',
            text: 'hi',
            timestamp: DateTime(2026),
            isFinal: true,
            speaker: 'Speaker 1',
            speakerIndex: 0,
            startSec: 1.5,
            endSec: 2.5,
          ),
        ],
        speakerNames: {'Speaker 1': 'Sneha'},
        coachingReport: CoachingReport(
          metrics: const [
            SpeakerMetrics(
              speakerKey: 'Speaker 1',
              talkTimeSec: 1,
              talkSharePct: 100,
              turnCount: 1,
              wordCount: 1,
              interruptionsMade: 0,
              interruptionsReceived: 0,
            ),
          ],
          reviews: const {'Speaker 1': 'Good pace.'},
          generatedAt: DateTime(2026),
        ),
      );
      final back = MeetingSession.fromJson(session.toJson());
      expect(back.nameFor('Speaker 1'), 'Sneha');
      expect(back.coachingReport!.reviews['Speaker 1'], 'Good pace.');
      expect(back.coachingReport!.metrics.single.talkSharePct, 100);
      expect(back.entries.first.endSec, 2.5);
      expect(back.entries.first.speakerIndex, 0);
    });
  });
}
