import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mitra_assistant/core/constants/app_constants.dart';
import 'package:mitra_assistant/core/theme/app_theme.dart';
import 'package:mitra_assistant/core/widgets/confirm_delete_dialog.dart';
import 'package:mitra_assistant/features/coaching/presentation/follow_ups_card.dart';
import 'package:mitra_assistant/features/history/domain/models/meeting_session.dart';
import 'package:mitra_assistant/features/history/presentation/history_view.dart';
import 'package:mitra_assistant/features/history/providers/history_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../tool/preview/preview_data.dart';

Future<ProviderContainer> openHistory(WidgetTester tester, {Size size = const Size(1100, 760)}) async {
  SharedPreferences.setMockInitialValues({
    AppConstants.prefMeetingHistory: sampleHistoryJson(),
    AppConstants.prefMyName: 'John',
  });
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final container = ProviderContainer();
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(theme: AppTheme.darkTheme, home: const Scaffold(body: HistoryView())),
    ),
  );
  await tester.pump(const Duration(milliseconds: 100));
  await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 250)));
  await tester.pump(const Duration(milliseconds: 300));
  return container;
}

void main() {
  testWidgets('lists meetings; the first is open with its outcomes, and clicking another opens it', (tester) async {
    await openHistory(tester);
    expect(find.text('Q3 budget review'), findsWidgets); // tile + detail title
    expect(find.text('Meeting notes'), findsOneWidget);
    expect(find.text('Hold hiring until the Q3 forecast is final'), findsOneWidget);

    await tester.tap(find.text('Launch planning').first);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Launch moves to the first week of November'), findsOneWidget);
    expect(find.text('Hold hiring until the Q3 forecast is final'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Transcript tab shows the speakers and the spoken text', (tester) async {
    await openHistory(tester);
    await tester.tap(find.text('Transcript'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Find in transcript'), findsOneWidget);
    expect(find.textContaining('lock the budget this week'), findsOneWidget);
    expect(find.text('John'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('searching the list matches transcript text and filters meetings', (tester) async {
    await openHistory(tester);
    await tester.enterText(find.byType(TextField).first, 'zzz-no-such-text');
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('No meeting matches.'), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, 'forecast');
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('No meeting matches.'), findsNothing);
  });

  testWidgets('delete needs the checkbox: nothing is deleted until it is ticked and confirmed', (tester) async {
    final container = await openHistory(tester);
    final before = container.read(historyNotifierProvider).sessions.length;

    await tester.tap(find.byTooltip('Delete meeting'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Delete this meeting?'), findsOneWidget);

    FilledButton deleteButton() => tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Delete'));
    expect(deleteButton().onPressed, isNull, reason: 'disabled until the box is ticked');

    // Cancel keeps it
    await tester.tap(find.text('Cancel'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(container.read(historyNotifierProvider).sessions.length, before);

    // tick, then delete
    await tester.tap(find.byTooltip('Delete meeting'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.byType(Checkbox));
    await tester.pump(const Duration(milliseconds: 200));
    expect(deleteButton().onPressed, isNotNull);
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 250)));
    await tester.pump(const Duration(milliseconds: 300));
    expect(container.read(historyNotifierProvider).sessions.length, before - 1);
  });

  testWidgets('delete-all also needs the checkbox', (tester) async {
    final container = await openHistory(tester);
    final before = container.read(historyNotifierProvider).sessions.length;
    await tester.tap(find.byTooltip('Delete all meetings'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.textContaining('Delete all $before meetings?'), findsOneWidget);
    expect(tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Delete all')).onPressed, isNull);
    await tester.tap(find.text('Cancel'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(container.read(historyNotifierProvider).sessions.length, before);
  });

  testWidgets('confirmDelete returns false on cancel and true only after ticking', (tester) async {
    bool? result;
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.darkTheme,
      home: Builder(
        builder: (ctx) => Scaffold(
          body: TextButton(onPressed: () async => result = await confirmDelete(ctx, title: 'T', message: 'M'), child: const Text('go')),
        ),
      ),
    ));
    await tester.tap(find.text('go'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Cancel'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(result, isFalse);

    await tester.tap(find.text('go'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.byType(Checkbox));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(result, isTrue);
  });

  testWidgets('follow-ups card lists only what is yours', (tester) async {
    final s = MeetingSession.fromJson(jsonDecode(sampleHistoryJson()).first as Map<String, dynamic>);
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.darkTheme,
      home: Scaffold(body: SingleChildScrollView(child: FollowUpsCard(session: s, meName: 'John'))),
    ));
    expect(find.text('Draft pricing options'), findsOneWidget); // owner John
    expect(find.text('Send the updated forecast'), findsNothing); // owner Priya
    expect(find.textContaining('Who approves'), findsNothing); // asked by Raj
  });
}
