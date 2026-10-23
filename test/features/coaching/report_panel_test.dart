import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mitra_assistant/core/constants/app_constants.dart';
import 'package:mitra_assistant/core/theme/app_theme.dart';
import 'package:mitra_assistant/features/coaching/data/participation_analyzer.dart';
import 'package:mitra_assistant/features/coaching/domain/models/coaching_feedback.dart';
import 'package:mitra_assistant/features/coaching/domain/models/coaching_report.dart';
import 'package:mitra_assistant/features/coaching/domain/models/meeting_digest.dart';
import 'package:mitra_assistant/features/coaching/presentation/coaching_report_dialog.dart';
import 'package:mitra_assistant/features/coaching/presentation/progress_dialog.dart';
import 'package:mitra_assistant/features/history/domain/models/meeting_session.dart';
import 'package:mitra_assistant/features/transcription/domain/models/transcript_entry.dart';
import 'package:shared_preferences/shared_preferences.dart';

TranscriptEntry e(String sp, String text, double s, double en) => TranscriptEntry(
      id: '$sp$s',
      text: text,
      timestamp: DateTime(2026),
      isFinal: true,
      speaker: sp,
      speakerIndex: sp == 'Speaker 1' ? 0 : 1,
      startSec: s,
      endSec: en,
    );

MeetingSession build({String? me}) {
  final entries = [
    e('Speaker 1', 'Um, so basically we should ship on Friday. ${List.filled(40, 'word').join(' ')}?', 0, 30),
    e('Speaker 2', 'Can we check the budget first? ${List.filled(30, 'word').join(' ')}', 31, 45),
    e('Speaker 1', 'Sure, ${List.filled(30, 'word').join(' ')}', 46, 60),
  ];
  return MeetingSession(
    id: 's1',
    title: 'Ship planning',
    aiSummary: '',
    startTime: DateTime(2026, 10, 19),
    endTime: DateTime(2026, 10, 19, 0, 30),
    entries: entries,
    speakerNames: me == null ? const {} : {me: 'Sneha'},
    meSpeakerKey: me,
    coachingReport: CoachingReport(metrics: ParticipationAnalyzer.analyze(entries), generatedAt: DateTime(2026)),
    digest: MeetingDigest(
      summary: 'Planned the release.',
      topics: const [DigestTopic('Release')],
      decisions: const [DigestDecision('Ship Friday')],
      actionItems: const [DigestAction('Check budget', owner: 'Sneha')],
      openQuestions: const [DigestQuestion('Who tests?', asker: 'Raj')],
      generatedAt: DateTime(2026),
    ),
    feedback: me == null
        ? null
        : CoachingFeedback(
            strengths: const [FeedbackItem('Clear proposal', evidence: 'we should ship on Friday')],
            improvements: const [FeedbackItem('Pause more', tip: 'Wait two seconds')],
            goalNotes: const ['Interruption goal met.'],
            generatedAt: DateTime(2026),
          ),
  );
}

Future<void> pump(WidgetTester tester, MeetingSession s, Widget child) async {
  SharedPreferences.setMockInitialValues({
    AppConstants.prefMeetingHistory: jsonEncode([s.toJson()]),
    AppConstants.prefMyName: 'Sneha',
  });
  tester.view.physicalSize = const Size(1000, 1200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        theme: AppTheme.darkTheme,
        home: Scaffold(body: SizedBox(width: 600, height: 1000, child: child)),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 200));
}

void main() {
  testWidgets('before choosing "me": asks which speaker you are, no scorecard', (tester) async {
    await pump(tester, build(), const CoachingReportPanel(sessionId: 's1'));
    expect(find.text('Which speaker are you?'), findsOneWidget);
    expect(find.text('Speaking pace'), findsNothing);
    expect(find.text('Your follow-ups'), findsOneWidget);
    expect(find.text('Pick which speaker you are to see your follow-ups.'), findsOneWidget);
    expect(find.text('Meeting notes'), findsNothing); // the full notes live in History
    expect(tester.takeException(), isNull);
  });

  testWidgets('after choosing "me": scorecard, goals, coaching and outcomes render', (tester) async {
    await pump(tester, build(me: 'Speaker 1'), const CoachingReportPanel(sessionId: 's1'));
    expect(find.text('You are'), findsOneWidget);
    expect(find.text('Speaking pace'), findsOneWidget);
    expect(find.text('Filler words'), findsOneWidget);
    expect(find.text('My goals'), findsOneWidget);
    expect(find.text('Clear proposal'), findsOneWidget);
    expect(find.textContaining('we should ship on Friday'), findsOneWidget);
    expect(find.textContaining('Try: Wait two seconds'), findsOneWidget);
    expect(find.text('EVERYONE IN THIS MEETING'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('progress panel shows trends for the named person', (tester) async {
    await pump(tester, build(me: 'Speaker 1'), const SizedBox(height: 700, child: ProgressPanel()));
    expect(find.text('Speaking pace (wpm)'), findsOneWidget);
    expect(find.textContaining('1 meeting'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

