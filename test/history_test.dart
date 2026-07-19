import 'package:flutter_test/flutter_test.dart';
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
  });
}
