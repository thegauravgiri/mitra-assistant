import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mitra_assistant/core/constants/app_constants.dart';
import 'package:mitra_assistant/core/theme/app_theme.dart';
import 'package:mitra_assistant/features/coaching/data/progress_service.dart';
import 'package:mitra_assistant/features/coaching/data/session_metrics.dart';
import 'package:mitra_assistant/features/coaching/presentation/coaching_report_dialog.dart';
import 'package:mitra_assistant/features/coaching/presentation/progress_dialog.dart';
import 'package:mitra_assistant/features/history/domain/models/meeting_session.dart';
import 'package:mitra_assistant/features/transcription/domain/models/transcript_entry.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A meeting saved before reports and word timings existed: one placeholder
/// speaker, no coachingReport, no timings.
MeetingSession oldMeeting({String id = 'old', Map<String, String> names = const {}, DateTime? start}) => MeetingSession(
      id: id,
      title: 'Old standup',
      aiSummary: '',
      startTime: start ?? DateTime(2026, 8, 20),
      endTime: DateTime(2026, 8, 20, 0, 20),
      entries: [
        for (var i = 0; i < 4; i++)
          TranscriptEntry(id: 'e$i', text: 'We should check the plan? Then ship it.', timestamp: DateTime(2026, 8, 20), isFinal: true),
      ],
      speakerNames: names,
    );

void main() {
  test('metricsOf analyses the transcript when there is no stored report', () {
    final m = metricsOf(oldMeeting());
    expect(m.length, 1);
    expect(m.single.speakerKey, 'Meeting Participant');
    expect(m.single.wordCount, greaterThan(20));
    expect(m.single.questionsAsked, 4);
    expect(m.single.paceWpm, isNull); // no timings: not measurable, not zero
  });

  test('an old meeting counts towards progress once you are named in it', () {
    final named = oldMeeting(id: 'a', names: {'Meeting Participant': 'John'});
    final later = oldMeeting(id: 'b', names: {'Meeting Participant': 'john'}, start: DateTime(2026, 9, 1));
    final points = ProgressService.forPerson([later, named, oldMeeting(id: 'c')], 'John');
    expect(points.map((p) => p.session.id), ['a', 'b']); // oldest first, unnamed one ignored
    expect(points.first.metrics.questionsAsked, 4);
  });

  Future<void> pump(WidgetTester tester, List<MeetingSession> sessions, Widget child) async {
    SharedPreferences.setMockInitialValues({
      AppConstants.prefMeetingHistory: jsonEncode([for (final s in sessions) s.toJson()]),
      AppConstants.prefMyName: 'John',
    });
    tester.view.physicalSize = const Size(900, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(child: MaterialApp(theme: AppTheme.darkTheme, home: Scaffold(body: SizedBox(width: 560, height: 800, child: child)))),
    );
    await tester.pump(const Duration(milliseconds: 100));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
    await tester.pump(const Duration(milliseconds: 200));
  }

  testWidgets('report for an old meeting offers "Which speaker are you?" instead of "No speaker data"', (tester) async {
    await pump(tester, [oldMeeting()], const CoachingReportPanel(sessionId: 'old'));
    expect(find.text('Which speaker are you?'), findsOneWidget);
    expect(find.text('No speaker data for this meeting.'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('My progress with nothing marked lists every meeting with tappable speakers', (tester) async {
    await pump(tester, [oldMeeting(), oldMeeting(id: 'old2')], const ProgressPanel());
    expect(find.text('Nothing to track yet'), findsOneWidget);
    expect(find.text('Old standup'), findsNWidgets(2));
    expect(find.text('The only speaker (older recording) · 100%'), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('tapping your speaker in My progress marks you and shows trends', (tester) async {
    await pump(tester, [oldMeeting()], const SizedBox(height: 800, child: ProgressPanel()));
    await tester.tap(find.text('The only speaker (older recording) · 100%'));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300))); // prefs write
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Nothing to track yet'), findsNothing);
    expect(find.text('Questions asked'), findsOneWidget);
    expect(find.textContaining('1 meeting'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('My progress shows trends once old meetings are marked', (tester) async {
    final names = {'Meeting Participant': 'John'};
    await pump(
      tester,
      [oldMeeting(id: 'a', names: names), oldMeeting(id: 'b', names: names, start: DateTime(2026, 9, 1))],
      const SizedBox(height: 700, child: ProgressPanel()),
    );
    expect(find.text('Questions asked'), findsOneWidget);
    expect(find.textContaining('2 meetings'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
