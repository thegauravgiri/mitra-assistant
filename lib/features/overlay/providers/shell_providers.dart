import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/window_control_service.dart';

/// Zen = compact live-meeting window (default). Workspace = wide window with
/// navigation. Both are the same native window, resized, so meeting state and
/// screen-capture protection carry over unchanged.
enum ShellMode { zen, zenCompact, workspace }

enum WorkspacePage { meeting, history, coaching, documents, repos, graph, settings }

class ShellState {
  final ShellMode mode;
  final WorkspacePage page;

  const ShellState({this.mode = ShellMode.zen, this.page = WorkspacePage.meeting});

  ShellState copyWith({ShellMode? mode, WorkspacePage? page}) =>
      ShellState(mode: mode ?? this.mode, page: page ?? this.page);
}

class ShellNotifier extends StateNotifier<ShellState> {
  ShellNotifier() : super(const ShellState());

  /// Which zen variant to return to when leaving the workspace.
  ShellMode _lastZen = ShellMode.zen;

  /// Resizes the window first, then switches the widget tree, so the old
  /// layout is never stretched into the new window size.
  Future<void> setMode(ShellMode mode, {WorkspacePage? page}) async {
    if (mode != state.mode) {
      if (state.mode != ShellMode.workspace) _lastZen = state.mode;
      await WindowControlService.instance.applyShellMode(
        mode == ShellMode.workspace ? WindowShape.workspace : (mode == ShellMode.zenCompact ? WindowShape.compact : WindowShape.zen),
        remember: state.mode != ShellMode.workspace,
      );
    }
    state = state.copyWith(mode: mode, page: page);
  }

  Future<void> openWorkspace({WorkspacePage? page}) =>
      setMode(ShellMode.workspace, page: page);

  Future<void> backToZen() => setMode(_lastZen);

  Future<void> toggleCompact() => setMode(
        state.mode == ShellMode.zenCompact ? ShellMode.zen : ShellMode.zenCompact,
      );

  void selectPage(WorkspacePage page) => state = state.copyWith(page: page);
}

final shellNotifierProvider = StateNotifierProvider<ShellNotifier, ShellState>((ref) {
  return ShellNotifier();
});

/// Lets one Workspace page open a specific meeting on another page
/// (History -> Coaching and back). The target page reads and clears it.
final historySelectionProvider = StateProvider<String?>((ref) => null);
final coachingSelectionProvider = StateProvider<String?>((ref) => null);
