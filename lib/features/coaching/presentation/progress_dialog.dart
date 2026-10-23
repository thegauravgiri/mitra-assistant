import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' show DateFormat;
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/design_tokens.dart';
import '../../history/providers/history_providers.dart';
import '../../settings/providers/settings_providers.dart';
import '../data/indicator_evaluator.dart';
import '../data/progress_service.dart';
import '../data/session_metrics.dart';
import '../../history/domain/models/meeting_session.dart';
import '../providers/coaching_providers.dart';
import 'ask_name.dart';
import 'sparkline.dart';

/// One person's metrics across meetings, as a trend per indicator.
/// Dialog body (Zen) and page section (Workspace).
class ProgressPanel extends ConsumerStatefulWidget {
  const ProgressPanel({super.key});

  @override
  ConsumerState<ProgressPanel> createState() => _ProgressPanelState();
}

class _ProgressPanelState extends ConsumerState<ProgressPanel> {
  String? _selected;

  @override
  Widget build(BuildContext context) {
    final sessions = ref.watch(historyNotifierProvider).sessions;
    final myName = ref.watch(settingsNotifierProvider.select((s) => s.myName));
    final names = ProgressService.knownNames(sessions);

    if (names.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: AppTheme.cardBackground,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: AppTheme.borderSubtle),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.show_chart_rounded, size: 18, color: AppTheme.primaryAccent),
                    SizedBox(width: AppSpacing.sm),
                    Text(
                      'Nothing to track yet',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                const Text(
                  'Progress follows you across meetings, and the app cannot tell which voice is yours '
                  'until you say so. Below, tap your speaker in each meeting you were in. '
                  'Trends appear once two are marked.',
                  style: TextStyle(fontSize: 12, color: AppTheme.textSecondary, height: 1.45),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Flexible(child: SingleChildScrollView(primary: false, child: MarkYourselfList(sessions: sessions))),
        ],
      );
    }
    final fallback = names.firstWhere((n) => n.toLowerCase() == myName.trim().toLowerCase(), orElse: () => names.first);
    final name = names.contains(_selected) ? _selected! : fallback;
    final points = ProgressService.forPerson(sessions, name);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButton<String>(
          value: name,
          isExpanded: true,
          dropdownColor: AppTheme.backgroundPureDark,
          style: const TextStyle(fontSize: 12, color: AppTheme.textPrimary),
          items: [for (final n in names) DropdownMenuItem(value: n, child: Text(n))],
          onChanged: (v) => setState(() => _selected = v),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          '${points.length} meeting${points.length == 1 ? '' : 's'}${points.length < 2 ? ' · needs two or more to show a trend' : ''}',
          style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
        ),
        const SizedBox(height: AppSpacing.sm),
        Flexible(
          child: SingleChildScrollView(
            primary: false,
            child: Column(
              children: [
                for (final id in IndicatorEvaluator.ids) _TrendRow(id: id, points: points),
                const SizedBox(height: AppSpacing.md),
                _MarkMore(sessions: sessions),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _TrendRow extends StatelessWidget {
  final String id;
  final List<ProgressPoint> points;

  const _TrendRow({required this.id, required this.points});

  @override
  Widget build(BuildContext context) {
    final series = IndicatorEvaluator.series(id, points);
    final present = series.whereType<double>().toList();
    final latest = present.isEmpty ? null : present.last;
    final delta = present.length < 2 ? null : present.last - present[present.length - 2];

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.xs + 2),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm + 2, vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppTheme.cardBackground,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppTheme.borderSubtle),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  IndicatorEvaluator.labels[id] ?? id,
                  style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                ),
                Text(
                  latest == null
                      ? 'n/a'
                      : '${latest.toStringAsFixed(id == 'fillers' || id == 'responseGap' ? 1 : 0)}'
                          '${delta == null ? '' : '  (${delta > 0 ? '+' : ''}${delta.toStringAsFixed(1)})'}',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                ),
              ],
            ),
          ),
          Sparkline(values: series, color: AppTheme.primaryAccent, width: 96),
        ],
      ),
    );
  }
}

/// Collapsed list at the bottom of the trends view for marking more meetings.
class _MarkMore extends StatelessWidget {
  final List<MeetingSession> sessions;

  const _MarkMore({required this.sessions});

  @override
  Widget build(BuildContext context) {
    final unmarked = sessions.where((s) => s.meSpeakerKey == null).length;
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: EdgeInsets.zero,
        title: Text(
          unmarked == 0 ? 'Meetings marked as yours' : 'Mark yourself in more meetings ($unmarked not marked)',
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textSecondary),
        ),
        children: [MarkYourselfList(sessions: sessions)],
      ),
    );
  }
}

/// Every saved meeting with its speakers as chips: tap yours. No AI call is
/// made here (that happens when you open the meeting's coaching report).
class MarkYourselfList extends ConsumerWidget {
  final List<MeetingSession> sessions;

  const MarkYourselfList({super.key, required this.sessions});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final myName = ref.watch(settingsNotifierProvider.select((s) => s.myName));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final s in sessions)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: AppSpacing.sm),
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppTheme.cardBackground,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: AppTheme.borderSubtle),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
                ),
                Text(
                  DateFormat('d MMM yyyy · HH:mm').format(s.startTime),
                  style: const TextStyle(fontSize: 10.5, color: AppTheme.textMuted),
                ),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final m in metricsOf(s))
                      ChoiceChip(
                        selected: s.meSpeakerKey == m.speakerKey,
                        label: Text(
                          speakerChipLabel(s, m),
                          style: const TextStyle(fontSize: 11),
                        ),
                        onSelected: (_) async {
                          var name = myName.trim();
                          if (name.isEmpty) {
                            name = (await askMyName(context))?.trim() ?? '';
                            if (name.isEmpty) return;
                          }
                          await ref.read(coachingNotifierProvider.notifier).setMe(s, m.speakerKey, name, coach: false);
                        },
                      ),
                  ],
                ),
              ],
            ),
          ),
      ],
    );
  }
}
