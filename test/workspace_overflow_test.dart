import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mitra_assistant/core/constants/app_constants.dart';
import 'package:mitra_assistant/core/theme/app_theme.dart';
import 'package:mitra_assistant/features/documents/providers/document_providers.dart';
import 'package:mitra_assistant/features/overlay/presentation/workspace_shell.dart';
import 'package:mitra_assistant/features/repos/providers/repo_providers.dart';
import 'package:mitra_assistant/features/overlay/providers/shell_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../tool/preview/preview_data.dart';

class _Docs extends DocumentNotifier {
  _Docs(super.ref) : super(persist: false) {
    state = DocumentState(documents: [sampleDocument()]);
  }
}

class _Shell extends ShellNotifier {
  _Shell(WorkspacePage page) {
    state = ShellState(mode: ShellMode.workspace, page: page);
  }
}

/// Every Workspace page at the smallest (900x600) and default (1100x760)
/// window sizes, with history that has NO notes yet (like real old meetings).
void main() {
  for (final size in const [Size(900, 600), Size(1100, 760)]) {
    for (final page in WorkspacePage.values) {
      testWidgets('${page.name} page at ${size.width.toInt()}x${size.height.toInt()} does not overflow', (tester) async {
        final sessions = [for (final m in sampleSessions()) (m.toJson()..remove('digest')..remove('feedback'))];
        SharedPreferences.setMockInitialValues({
          AppConstants.prefMeetingHistory: jsonEncode(sessions),
          AppConstants.prefMyName: 'John',
        });
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
          const MethodChannel(AppConstants.audioCaptureChannel),
          (call) async => call.method == 'listInputDevices' ? <dynamic>[] : null,
        );
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              documentNotifierProvider.overrideWith((ref) => _Docs(ref)),
              repoNotifierProvider.overrideWith((ref) => RepoNotifier(ref, persist: false)),
              shellNotifierProvider.overrideWith((ref) => _Shell(page)),
            ],
            child: MaterialApp(theme: AppTheme.darkTheme, home: const Scaffold(body: WorkspaceShell())),
          ),
        );
        await tester.pump(const Duration(milliseconds: 200));
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 400)));
        await tester.pump(const Duration(milliseconds: 300));
        expect(tester.takeException(), isNull);
      });
    }
  }
}
