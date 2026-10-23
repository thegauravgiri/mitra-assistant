import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../core/theme/speaker_colors.dart';
import '../../history/domain/models/meeting_session.dart';
import '../../history/providers/history_providers.dart';
import '../../settings/providers/settings_providers.dart';
import '../data/report_export_service.dart';
import '../data/report_view_model.dart';
import '../data/session_metrics.dart';
import '../domain/models/speaker_metrics.dart';
import '../providers/coaching_providers.dart';
import 'ask_name.dart';
import 'feedback_card.dart';
import 'goals_card.dart';
import 'section_card.dart';
import 'follow_ups_card.dart';
import 'scorecard.dart';

/// Full coaching report for one saved meeting: who you are, scorecard, goals,
/// personalised coaching, your follow-ups, and everyone's numbers. Needs a
/// height-bounded parent. The full meeting notes live in History.
class CoachingReportPanel extends ConsumerWidget {
  final String sessionId;

  /// Opens this meeting's full notes (History). Null hides the button.
  final VoidCallback? onOpenNotes;

  const CoachingReportPanel({super.key, required this.sessionId, this.onOpenNotes});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessions = ref.watch(historyNotifierProvider).sessions;
    final matches = sessions.where((s) => s.id == sessionId);
    if (matches.isEmpty) {
      return const Text(
        'Session no longer exists.',
        style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
      );
    }
    final session = matches.first;
    final metrics = metricsOf(session);
    final goals = ref.watch(settingsNotifierProvider.select((s) => s.goals));
    final vm = ReportViewModel.build(session, sessions, goals);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                session.title,
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (metrics.isNotEmpty)
              PopupMenuButton<String>(
                tooltip: 'Export',
                icon: const Icon(Icons.ios_share_rounded, size: 18),
                color: AppTheme.backgroundPureDark,
                onSelected: (v) => v == 'md'
                    ? _export(context, ReportExportService.exportMarkdown(session), 'Report')
                    : _export(context, ReportExportService.exportSessionJson(session), 'Session'),
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'md', child: Text('Export report (.md)')),
                  PopupMenuItem(value: 'json', child: Text('Export session (.json)')),
                ],
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        if (metrics.isEmpty)
          const Hint('No speaker data for this meeting.')
        else
          Flexible(
            child: LayoutBuilder(
              builder: (context, box) {
                final wide = box.maxWidth >= 720;
                final coaching = FeedbackCard(session: session);
                final goalsCard = GoalsCard(vm: vm);
                final followUps = FollowUpsCard(session: session, meName: vm.meName, onOpenNotes: onOpenNotes);
                const gap = SizedBox(height: AppSpacing.md);

                return SingleChildScrollView(
                  primary: false, // desktop shares one primary controller across pages otherwise
                  padding: const EdgeInsets.only(right: AppSpacing.xs),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _MePicker(session: session, metrics: metrics),
                      const SizedBox(height: AppSpacing.lg),
                      if (vm.me != null) ...[
                        Scorecard(vm: vm),
                        const SizedBox(height: AppSpacing.lg),
                      ],
                      if (wide)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: Column(children: [coaching, gap, goalsCard])),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(child: followUps),
                          ],
                        )
                      else ...[
                        coaching,
                        gap,
                        goalsCard,
                        gap,
                        followUps,
                      ],
                      const SizedBox(height: AppSpacing.lg),
                      const Text(
                        'EVERYONE IN THIS MEETING',
                        style: TextStyle(
                          fontSize: 10.5,
                          letterSpacing: 0.8,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textMuted,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Wrap(
                        spacing: AppSpacing.md,
                        runSpacing: AppSpacing.md,
                        children: [
                          for (final m in metrics)
                            SizedBox(
                              width: wide ? (box.maxWidth - AppSpacing.md) / 2 - 1 : box.maxWidth,
                              child: _SpeakerBlock(
                                key: ValueKey('${session.id}/${m.speakerKey}'),
                                session: session,
                                metrics: m,
                                review: session.coachingReport?.reviews[m.speakerKey],
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.md),
                    ],
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}

/// "Which speaker are you?" chips. Choosing one names that speaker (using the
/// profile name) and asks for personalised coaching.
class _MePicker extends ConsumerWidget {
  final MeetingSession session;
  final List<SpeakerMetrics> metrics;

  const _MePicker({required this.session, required this.metrics});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final myName = ref.watch(settingsNotifierProvider.select((s) => s.myName));

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppTheme.primaryAccent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppTheme.primaryAccent.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            session.meSpeakerKey == null ? 'Which speaker are you?' : 'You are',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
          ),
          const SizedBox(height: AppSpacing.xs + 2),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final m in metrics)
                ChoiceChip(
                  selected: session.meSpeakerKey == m.speakerKey,
                  label: Text(
                    speakerChipLabel(session, m),
                    style: const TextStyle(fontSize: 11),
                  ),
                  avatar: CircleAvatar(radius: 5, backgroundColor: SpeakerColors.forLabel(m.speakerKey)),
                  onSelected: (_) async {
                    var name = myName.trim();
                    if (name.isEmpty) {
                      name = (await askMyName(context))?.trim() ?? '';
                      if (name.isEmpty) return;
                    }
                    await ref.read(coachingNotifierProvider.notifier).setMe(session, m.speakerKey, name);
                  },
                ),
            ],
          ),
          if (session.meSpeakerKey == null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                'Audio is mixed, so the app cannot tell which voice is yours. '
                '${myName.isEmpty ? '' : 'You will be shown as $myName.'}',
                style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
              ),
            ),
        ],
      ),
    );
  }
}

Future<void> _export(BuildContext context, Future<dynamic> pending, String label) async {
  final messenger = ScaffoldMessenger.of(context);
  final file = await pending;
  messenger.showSnackBar(
    SnackBar(
      content: Text(file == null ? '$label export failed.' : '$label saved: ${file.path}'),
      backgroundColor: file == null ? AppTheme.panicAccent : AppTheme.secondaryAccent,
      duration: const Duration(seconds: 4),
    ),
  );
}

class _SpeakerBlock extends ConsumerStatefulWidget {
  final MeetingSession session;
  final SpeakerMetrics metrics;
  final String? review;

  const _SpeakerBlock({
    super.key,
    required this.session,
    required this.metrics,
    required this.review,
  });

  @override
  ConsumerState<_SpeakerBlock> createState() => _SpeakerBlockState();
}

class _SpeakerBlockState extends ConsumerState<_SpeakerBlock> {
  late final TextEditingController _name;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(
      text: widget.session.speakerNames[widget.metrics.speakerKey] ?? '',
    );
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  String _fmt(double sec) {
    final m = sec ~/ 60;
    final s = (sec % 60).round();
    return m > 0 ? '${m}m ${s}s' : '${s}s';
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.metrics;
    final color = SpeakerColors.forLabel(m.speakerKey);
    final extras = [
      if (m.paceWpm != null) '${m.paceWpm!.toStringAsFixed(0)} wpm',
      if (m.fillersPerMin != null) '${m.fillersPerMin!.toStringAsFixed(1)} fillers/min',
      '${m.questionsAsked} questions',
    ].join(' · ');

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppTheme.cardBackground,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppTheme.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
              const SizedBox(width: AppSpacing.xs + 2),
              Expanded(
                child: TextField(
                  controller: _name,
                  style: const TextStyle(fontSize: 12, color: AppTheme.textPrimary),
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: m.speakerKey,
                    hintStyle: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                    border: InputBorder.none,
                    suffixIcon: const Icon(Icons.edit_outlined, size: 12, color: AppTheme.textMuted),
                    suffixIconConstraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                  ),
                  onSubmitted: (v) => ref
                      .read(coachingNotifierProvider.notifier)
                      .renameSpeaker(widget.session, m.speakerKey, v),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: (m.talkSharePct / 100).clamp(0, 1),
              minHeight: 6,
              color: color,
              backgroundColor: AppTheme.borderSubtle,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            '${m.talkSharePct.toStringAsFixed(0)}% talk · ${_fmt(m.talkTimeSec)} · '
            '${m.turnCount} turns · interrupted ${m.interruptionsMade}x, was interrupted ${m.interruptionsReceived}x',
            style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary),
          ),
          Text(extras, style: const TextStyle(fontSize: 10, color: AppTheme.textMuted)),
          if (widget.review != null) ...[
            const SizedBox(height: AppSpacing.xs + 2),
            Text(
              widget.review!,
              style: const TextStyle(fontSize: 11, color: AppTheme.textPrimary, height: 1.4),
            ),
          ],
        ],
      ),
    );
  }
}
