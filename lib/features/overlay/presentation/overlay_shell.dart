import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'compact_mode.dart';
import 'expanded_mode.dart';
import 'workspace_shell.dart';
import '../providers/shell_providers.dart';
import '../../../core/theme/design_tokens.dart';

class OverlayShell extends ConsumerWidget {
  const OverlayShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(shellNotifierProvider.select((s) => s.mode));
    final shell = ref.read(shellNotifierProvider.notifier);

    final Widget child;
    switch (mode) {
      case ShellMode.zenCompact:
        child = CompactModeView(
          key: const ValueKey('compact_view'),
          onExpand: shell.toggleCompact,
        );
      case ShellMode.workspace:
        child = const WorkspaceShell(key: ValueKey('workspace_view'));
      case ShellMode.zen:
        child = ExpandedModeView(
          key: const ValueKey('zen_view'),
          onCollapse: shell.toggleCompact,
          onOpenWorkspace: () => shell.openWorkspace(),
          onOpenSettings: () => shell.openWorkspace(page: WorkspacePage.settings),
        );
    }

    return Material(
      color: Colors.transparent,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: AnimatedSwitcher(
          duration: AppDuration.normal,
          switchInCurve: Curves.easeInOut,
          switchOutCurve: Curves.easeInOut,
          transitionBuilder: (child, animation) => FadeTransition(
            opacity: animation,
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.96, end: 1.0).animate(animation),
              child: child,
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}
