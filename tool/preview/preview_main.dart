// Screenshot harness: runs the real app with sample data and screen-capture
// protection OFF so the window can be captured. Never ships.
//
//   flutter build macos --debug -t tool/preview/preview_main.dart
//   PAGE=coaching build/macos/Build/Products/Debug/mitra_assistant.app/Contents/MacOS/mitra_assistant
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mitra_assistant/app.dart';
import 'package:mitra_assistant/features/documents/presentation/graph_3d_view.dart';
import 'package:mitra_assistant/features/documents/presentation/graph_view.dart';
import 'package:mitra_assistant/features/documents/providers/document_providers.dart';
import 'package:mitra_assistant/features/overlay/data/window_control_service.dart';
import 'package:mitra_assistant/features/overlay/presentation/workspace_shell.dart';
import 'package:mitra_assistant/features/overlay/providers/shell_providers.dart';
import 'package:mitra_assistant/features/repos/providers/repo_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'preview_data.dart';

final _page = Platform.environment['PAGE'] ?? 'zen';

class _SeededDocs extends DocumentNotifier {
  _SeededDocs(super.ref) : super(persist: false) {
    state = DocumentState(documents: [sampleDocument()]);
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // ignore: invalid_use_of_visible_for_testing_member
  SharedPreferences.setMockInitialValues(samplePrefs(old: Platform.environment['OLD'] == '1'));
  GraphView.debugStartOnDocuments = _page.endsWith('-docs');
  WorkspaceShell.debugCoachingProgress = _page.endsWith('-progress');
  final sel = Platform.environment['SELECT'] ?? '';
  Graph3DCanvas.debugInitialSelection = sel.isEmpty ? null : sel; // in-memory only; real prefs untouched
  await WindowControlService.instance.initializeWindow();
  await WindowControlService.instance.disableScreenProtection();

  runApp(
    ProviderScope(
      overrides: [
        documentNotifierProvider.overrideWith((ref) => _SeededDocs(ref)),
        repoNotifierProvider.overrideWith((ref) => RepoNotifier(ref, persist: false)),
      ],
      child: const _Boot(),
    ),
  );
}

class _Boot extends ConsumerStatefulWidget {
  const _Boot();

  @override
  ConsumerState<_Boot> createState() => _BootState();
}

class _BootState extends ConsumerState<_Boot> {
  @override
  void initState() {
    super.initState();
    Future(() async {
      await Future<void>.delayed(const Duration(seconds: 1));
      if (_page == 'zen') return;
      final page = WorkspacePage.values.firstWhere((p) => p.name == _page.split('-').first, orElse: () => WorkspacePage.meeting);
      await ref.read(shellNotifierProvider.notifier).openWorkspace(page: page);
      await WindowControlService.instance.disableScreenProtection(); // resize re-enables it
      if (_page.startsWith('repos')) {
        await ref.read(repoNotifierProvider.notifier).addRepo(Platform.environment['REPO'] ?? Directory.current.path);
      }
    });
  }

  @override
  Widget build(BuildContext context) => const MitraApp();
}
