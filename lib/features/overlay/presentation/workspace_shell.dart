import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:window_manager/window_manager.dart';
import '../../ai_engine/presentation/insight_view.dart';
import '../../coaching/presentation/coaching_report_dialog.dart';
import '../../coaching/presentation/progress_dialog.dart';
import '../../documents/presentation/documents_page.dart';
import '../../documents/presentation/graph_view.dart';
import '../../history/presentation/history_view.dart';
import '../../history/providers/history_providers.dart';
import '../../settings/presentation/settings_view.dart';
import '../../transcription/presentation/transcript_view.dart';
import '../data/window_control_service.dart';
import '../providers/shell_providers.dart';
import 'start_stop_button.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../core/widgets/empty_state.dart';

const _navItems = <(WorkspacePage, IconData, String)>[
  (WorkspacePage.meeting, Icons.mic_rounded, 'Meeting'),
  (WorkspacePage.history, Icons.history_rounded, 'History'),
  (WorkspacePage.coaching, Icons.insights_rounded, 'Coaching'),
  (WorkspacePage.documents, Icons.description_rounded, 'Documents'),
  (WorkspacePage.graph, Icons.hub_rounded, 'Graph'),
  (WorkspacePage.settings, Icons.tune_rounded, 'Settings'),
];

/// Wide window with navigation. Same native window as Zen (so screen-capture
/// protection applies), just resized by [ShellNotifier].
class WorkspaceShell extends ConsumerWidget {
  /// Screenshot harness only.
  static bool debugCoachingProgress = false;

  const WorkspaceShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shell = ref.watch(shellNotifierProvider);
    final notifier = ref.read(shellNotifierProvider.notifier);

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.backgroundDark,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: AppTheme.borderGlow.withValues(alpha: 0.4),
          width: 1.5,
        ),
        boxShadow: AppShadows.medium,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Column(
          children: [
            _TopBar(
              onNeedSettings: () => notifier.selectPage(WorkspacePage.settings),
            ),
            Expanded(
              child: Row(
                children: [
                  _NavRail(current: shell.page, onSelect: notifier.selectPage),
                  const VerticalDivider(width: 1, color: AppTheme.borderSubtle),
                  Expanded(
                    child: IndexedStack(
                      index: WorkspacePage.values.indexOf(shell.page),
                      children: [
                        for (final p in WorkspacePage.values)
                          _page(p, notifier),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _page(WorkspacePage page, ShellNotifier notifier) {
    switch (page) {
      case WorkspacePage.meeting:
        return Row(
          children: [
            Expanded(
              flex: 5,
              child: InsightView(
                onOpenSettings: () =>
                    notifier.selectPage(WorkspacePage.settings),
              ),
            ),
            const VerticalDivider(width: 1, color: AppTheme.borderSubtle),
            const Expanded(flex: 4, child: TranscriptView()),
          ],
        );
      case WorkspacePage.history:
        return const HistoryView();
      case WorkspacePage.coaching:
        return const _CoachingPage();
      case WorkspacePage.documents:
        return DocumentsPage(
          onOpenGraph: () => notifier.selectPage(WorkspacePage.graph),
        );
      case WorkspacePage.graph:
        return const GraphView();
      case WorkspacePage.settings:
        return const SettingsView();
    }
  }
}

class _TopBar extends ConsumerWidget {
  final VoidCallback onNeedSettings;

  const _TopBar({required this.onNeedSettings});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onPanStart: (_) => windowManager.startDragging(),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: const BoxDecoration(
          color: AppTheme.cardBackground,
          border: Border(bottom: BorderSide(color: AppTheme.borderSubtle)),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.drag_indicator_rounded,
              size: 16,
              color: AppTheme.textMuted,
            ),
            const SizedBox(width: AppSpacing.xs),
            const Text(
              'Mitra Assistant',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            const ElapsedBadge(),
            const Spacer(),
            StartStopButton(onNeedSettings: onNeedSettings),
            const SizedBox(width: AppSpacing.md),
            IconButton(
              icon: const Icon(
                Icons.visibility_off_outlined,
                size: 17,
                color: AppTheme.warningAccent,
              ),
              tooltip: 'Panic Hide (⌘/Ctrl+Shift+H)',
              onPressed: () => WindowControlService.instance.panicHide(),
            ),
            TextButton.icon(
              onPressed: () =>
                  ref.read(shellNotifierProvider.notifier).backToZen(),
              icon: const Icon(Icons.close_fullscreen_rounded, size: 15),
              label: const Text('Zen mode'),
            ),
            IconButton(
              icon: const Icon(Icons.remove_rounded, size: 18),
              tooltip: 'Minimise',
              onPressed: () => windowManager.minimize(),
            ),
            IconButton(
              icon: const Icon(Icons.close_rounded, size: 18),
              tooltip: 'Quit',
              onPressed: () => windowManager.close(),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavRail extends StatelessWidget {
  final WorkspacePage current;
  final ValueChanged<WorkspacePage> onSelect;

  const _NavRail({required this.current, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 180,
      color: AppTheme.backgroundPureDark.withValues(alpha: 0.5),
      padding: const EdgeInsets.all(AppSpacing.sm),
      child: Column(
        children: [
          for (final (page, icon, label) in _navItems)
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Material(
                color: page == current
                    ? AppTheme.primaryAccent.withValues(alpha: 0.18)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(AppRadius.md),
                child: InkWell(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  onTap: () => onSelect(page),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.sm + 2,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          icon,
                          size: 17,
                          color: page == current
                              ? AppTheme.primaryAccent
                              : AppTheme.textSecondary,
                        ),
                        const SizedBox(width: AppSpacing.sm + 2),
                        Text(
                          label,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: page == current
                                ? FontWeight.bold
                                : FontWeight.w500,
                            color: page == current
                                ? AppTheme.textPrimary
                                : AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Sessions on the left; on the right either the selected meeting's report or
/// your progress across meetings.
class _CoachingPage extends ConsumerStatefulWidget {
  const _CoachingPage();

  @override
  ConsumerState<_CoachingPage> createState() => _CoachingPageState();
}

class _CoachingPageState extends ConsumerState<_CoachingPage> {
  String? _sessionId;
  bool _progress = WorkspaceShell.debugCoachingProgress;

  @override
  Widget build(BuildContext context) {
    final sessions = ref.watch(historyNotifierProvider).sessions;
    if (sessions.isEmpty) {
      return const EmptyStateWidget(
        icon: Icons.insights_outlined,
        title: 'No meetings yet',
        description: 'Finish a meeting and its coaching report shows up here.',
      );
    }
    // another page (History) asked to open a meeting here
    ref.listen<String?>(coachingSelectionProvider, (_, id) {
      if (id == null) return;
      setState(() {
        _sessionId = id;
        _progress = false;
      });
      ref.read(coachingSelectionProvider.notifier).state = null;
    });
    final selected = sessions.firstWhere((s) => s.id == _sessionId, orElse: () => sessions.first);

    return Row(
      children: [
        SizedBox(
          width: 248,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.sm),
                child: Text(
                  'MEETINGS',
                  style: TextStyle(fontSize: 10.5, letterSpacing: 0.8, fontWeight: FontWeight.w700, color: AppTheme.textMuted),
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  children: [
                    for (final s in sessions)
                      _SessionTile(
                        title: s.title,
                        date: DateFormat('d MMM yyyy · HH:mm').format(s.startTime),
                        hasMe: s.meSpeakerKey != null,
                        selected: !_progress && s.id == selected.id,
                        onTap: () => setState(() {
                          _sessionId = s.id;
                          _progress = false;
                        }),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(AppSpacing.sm),
                child: _SessionTile(
                  title: 'My progress',
                  date: 'Trends across meetings',
                  icon: Icons.show_chart_rounded,
                  selected: _progress,
                  onTap: () => setState(() => _progress = true),
                ),
              ),
            ],
          ),
        ),
        const VerticalDivider(width: 1, color: AppTheme.borderSubtle),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: _progress
                ? const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'My progress',
                        style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                      ),
                      SizedBox(height: AppSpacing.md),
                      Expanded(child: ProgressPanel()),
                    ],
                  )
                : CoachingReportPanel(
                    sessionId: selected.id,
                    onOpenNotes: () {
                      ref.read(historySelectionProvider.notifier).state = selected.id;
                      ref.read(shellNotifierProvider.notifier).selectPage(WorkspacePage.history);
                    },
                  ),
          ),
        ),
      ],
    );
  }
}

class _SessionTile extends StatelessWidget {
  final String title;
  final String date;
  final bool selected;
  final bool hasMe;
  final IconData? icon;
  final VoidCallback onTap;

  const _SessionTile({
    required this.title,
    required this.date,
    required this.selected,
    required this.onTap,
    this.hasMe = false,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: selected ? AppTheme.primaryAccent.withValues(alpha: 0.18) : Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.md),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm + 2),
            child: Row(
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 16, color: AppTheme.primaryAccent),
                  const SizedBox(width: AppSpacing.sm),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(date, style: const TextStyle(fontSize: 10.5, color: AppTheme.textMuted)),
                    ],
                  ),
                ),
                if (hasMe)
                  const Tooltip(
                    message: 'Coached',
                    child: Icon(Icons.check_circle_rounded, size: 14, color: Color(0xFF0CA30C)),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
