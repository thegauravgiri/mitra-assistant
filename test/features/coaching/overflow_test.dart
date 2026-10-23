import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mitra_assistant/core/constants/app_constants.dart';
import 'package:mitra_assistant/core/theme/app_theme.dart';
import 'package:mitra_assistant/features/coaching/presentation/backfill_bar.dart';
import 'package:mitra_assistant/features/coaching/presentation/coaching_report_dialog.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../tool/preview/preview_data.dart';

/// Renders the coaching report at the real window sizes and fails on any
/// RenderFlex overflow.
void main() {
  Future<void> open(WidgetTester tester, Size window, Widget Function(BuildContext) launcher) async {
    SharedPreferences.setMockInitialValues({
      AppConstants.prefMeetingHistory: sampleHistoryJson(),
      AppConstants.prefMyName: 'John',
    });
    tester.view.physicalSize = window;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(theme: AppTheme.darkTheme, home: Scaffold(body: Builder(builder: launcher))),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets('Workspace width (800x700 content): report does not overflow', (tester) async {
    await open(tester, const Size(1000, 800), (ctx) => const Padding(
          padding: EdgeInsets.all(24),
          child: SizedBox(width: 760, height: 700, child: CoachingReportPanel(sessionId: 'm4')),
        ));
    expect(tester.takeException(), isNull);
  });

  testWidgets('sidebar width (232px): "Build notes for older meetings" does not overflow', (tester) async {
    // older meetings without notes, as in real history
    final old = [
      for (final m in sampleSessions().take(3)) (m.toJson()..remove('digest')),
    ];
    SharedPreferences.setMockInitialValues({AppConstants.prefMeetingHistory: jsonEncode(old)});
    tester.view.physicalSize = const Size(900, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: const Scaffold(body: Align(alignment: Alignment.topLeft, child: SizedBox(width: 232, child: BackfillBar()))),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.textContaining('Build notes for'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
