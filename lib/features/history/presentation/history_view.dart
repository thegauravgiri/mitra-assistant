import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../core/theme/speaker_colors.dart';
import '../../../core/widgets/confirm_delete_dialog.dart';
import '../../../core/widgets/empty_state.dart';
import '../../coaching/data/session_metrics.dart';
import '../../coaching/presentation/outcomes_card.dart';
import '../../overlay/providers/shell_providers.dart';
import '../../settings/providers/settings_providers.dart';
import '../data/transcript_blocks.dart';
import '../domain/models/meeting_session.dart';
import '../providers/history_providers.dart';

/// Workspace page: every saved meeting. Pick one on the left to read its
/// outcomes and transcript on the right.
class HistoryView extends ConsumerStatefulWidget {
  const HistoryView({super.key});

  @override
  ConsumerState<HistoryView> createState() => _HistoryViewState();
}

class _HistoryViewState extends ConsumerState<HistoryView> {
  final TextEditingController _search = TextEditingController();
  String? _selectedId;
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _clearAll(int count) async {
    final ok = await confirmDelete(
      context,
      title: 'Delete all $count meetings?',
      message: 'Every saved meeting is removed with its transcript, notes and coaching, '
          'and any exported CSV files are deleted from disk.',
      checkboxLabel: 'Yes, delete all $count meetings',
      confirmLabel: 'Delete all',
    );
    if (ok) {
      await ref.read(historyNotifierProvider.notifier).clearHistory();
      setState(() => _selectedId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(historyNotifierProvider);
    final sessions = state.sessions;

    // another page (Coaching) asked to open a meeting here
    ref.listen<String?>(historySelectionProvider, (_, id) {
      if (id == null) return;
      setState(() {
        _selectedId = id;
        _query = '';
        _search.clear();
      });
      ref.read(historySelectionProvider.notifier).state = null;
    });

    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator(color: AppTheme.primaryAccent, strokeWidth: 2));
    }
    if (sessions.isEmpty) {
      return const EmptyStateWidget(
        icon: Icons.history_toggle_off_rounded,
        title: 'No meetings yet',
        description: 'When you end a meeting, its transcript, notes and coaching are saved here.',
      );
    }

    final q = _query.trim().toLowerCase();
    final shown = q.isEmpty
        ? sessions
        : [
            for (final s in sessions)
              if (s.title.toLowerCase().contains(q) ||
                  (s.digest?.summary ?? s.aiSummary).toLowerCase().contains(q) ||
                  s.entries.any((e) => e.text.toLowerCase().contains(q)))
                s,
          ];
    final selected = sessions.firstWhere(
      (s) => s.id == _selectedId,
      orElse: () => shown.isNotEmpty ? shown.first : sessions.first,
    );

    return Row(
      children: [
        SizedBox(
          width: 320,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.sm, AppSpacing.sm),
                child: Row(
                  children: [
                    const Text(
                      'MEETINGS',
                      style: TextStyle(fontSize: 10.5, letterSpacing: 0.8, fontWeight: FontWeight.w700, color: AppTheme.textMuted),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryAccent.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                      ),
                      child: Text(
                        '${sessions.length}',
                        style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      tooltip: 'Delete all meetings',
                      icon: const Icon(Icons.delete_sweep_rounded, size: 18, color: AppTheme.textMuted),
                      onPressed: () => _clearAll(sessions.length),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                child: TextField(
                  controller: _search,
                  onChanged: (v) => setState(() => _query = v),
                  style: const TextStyle(fontSize: 12.5),
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: 'Search titles and transcripts',
                    hintStyle: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                    prefixIcon: const Icon(Icons.search_rounded, size: 16),
                    suffixIcon: _query.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.close_rounded, size: 14),
                            onPressed: () => setState(() {
                              _query = '';
                              _search.clear();
                            }),
                          ),
                    filled: true,
                    fillColor: AppTheme.cardBackground,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      borderSide: const BorderSide(color: AppTheme.borderSubtle),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      borderSide: const BorderSide(color: AppTheme.borderSubtle),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Expanded(
                child: shown.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.all(AppSpacing.lg),
                        child: Text('No meeting matches.', style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                      )
                    : ListView.builder(
                        primary: false,
                        padding: const EdgeInsets.fromLTRB(AppSpacing.sm, 0, AppSpacing.sm, AppSpacing.sm),
                        itemCount: shown.length,
                        itemBuilder: (_, i) => _MeetingTile(
                          session: shown[i],
                          selected: shown[i].id == selected.id,
                          onTap: () => setState(() => _selectedId = shown[i].id),
                        ),
                      ),
              ),
            ],
          ),
        ),
        const VerticalDivider(width: 1, color: AppTheme.borderSubtle),
        Expanded(
          child: _MeetingDetail(
            key: ValueKey(selected.id),
            session: selected,
            searchHint: q,
            onDeleted: () => setState(() => _selectedId = null),
          ),
        ),
      ],
    );
  }
}

String _duration(MeetingSession s) {
  final d = s.endTime.difference(s.startTime);
  return d.inMinutes > 0 ? '${d.inMinutes} min' : '${d.inSeconds} sec';
}

class _MeetingTile extends StatelessWidget {
  final MeetingSession session;
  final bool selected;
  final VoidCallback onTap;

  const _MeetingTile({required this.session, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final summary = (session.digest?.summary.isNotEmpty == true ? session.digest!.summary : session.aiSummary).trim();
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: selected ? AppTheme.primaryAccent.withValues(alpha: 0.18) : Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.md),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        session.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ),
                    if (session.digest != null)
                      const Tooltip(
                        message: 'Notes ready',
                        child: Padding(
                          padding: EdgeInsets.only(left: 6),
                          child: Icon(Icons.fact_check_rounded, size: 13, color: AppTheme.primaryAccent),
                        ),
                      ),
                    if (session.feedback != null)
                      const Tooltip(
                        message: 'Coached',
                        child: Padding(
                          padding: EdgeInsets.only(left: 6),
                          child: Icon(Icons.check_circle_rounded, size: 13, color: Color(0xFF0CA30C)),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '${DateFormat('d MMM yyyy · HH:mm').format(session.startTime)} · ${_duration(session)}',
                  style: const TextStyle(fontSize: 10.5, color: AppTheme.textMuted),
                ),
                if (summary.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    summary,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary, height: 1.35),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MeetingDetail extends ConsumerStatefulWidget {
  final MeetingSession session;
  final String searchHint; // pre-fills the transcript search when you searched the list
  final VoidCallback onDeleted;

  const _MeetingDetail({super.key, required this.session, required this.searchHint, required this.onDeleted});

  @override
  ConsumerState<_MeetingDetail> createState() => _MeetingDetailState();
}

class _MeetingDetailState extends ConsumerState<_MeetingDetail> {
  late int _tab = widget.searchHint.isEmpty ? 0 : 1; // searching text lands on the transcript

  Future<void> _delete() async {
    final s = widget.session;
    final ok = await confirmDelete(
      context,
      title: 'Delete this meeting?',
      message: '“${s.title}” is removed with its transcript, notes and coaching. '
          'Its exported CSV file, if any, is deleted from disk too.',
    );
    if (!ok) return;
    await ref.read(historyNotifierProvider.notifier).deleteSession(s.id);
    widget.onDeleted();
  }

  Future<void> _exportCsv() async {
    final messenger = ScaffoldMessenger.of(context);
    final path = await ref.read(historyNotifierProvider.notifier).exportSessionCsv(widget.session);
    messenger.showSnackBar(
      SnackBar(
        content: Text(path != null ? 'CSV saved: $path' : 'Failed to export CSV file.'),
        backgroundColor: path != null ? AppTheme.secondaryAccent : AppTheme.panicAccent,
        duration: const Duration(seconds: 4),
        action: path == null
            ? null
            : SnackBarAction(
                label: 'Copy path',
                textColor: Colors.white,
                onPressed: () => Clipboard.setData(ClipboardData(text: path)),
              ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.session;
    final myName = ref.watch(settingsNotifierProvider.select((x) => x.myName));
    final meName = s.meSpeakerKey != null ? s.nameFor(s.meSpeakerKey!) : (myName.isEmpty ? null : myName);
    final speakers = metricsOf(s).length;

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  s.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                ),
              ),
              IconButton(
                tooltip: 'Delete meeting',
                icon: const Icon(Icons.delete_outline_rounded, size: 20, color: AppTheme.panicAccent),
                onPressed: _delete,
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${DateFormat('EEEE d MMMM yyyy · HH:mm').format(s.startTime)} · ${_duration(s)} · '
            '$speakers speaker${speakers == 1 ? '' : 's'}',
            style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SegmentedButton<int>(
                segments: const [
                  ButtonSegment(value: 0, label: Text('Notes'), icon: Icon(Icons.fact_check_rounded, size: 15)),
                  ButtonSegment(value: 1, label: Text('Transcript'), icon: Icon(Icons.subtitles_rounded, size: 15)),
                ],
                selected: {_tab},
                onSelectionChanged: (v) => setState(() => _tab = v.first),
                showSelectedIcon: false,
              ),
              FilledButton.tonalIcon(
                onPressed: () {
                  ref.read(coachingSelectionProvider.notifier).state = s.id;
                  ref.read(shellNotifierProvider.notifier).selectPage(WorkspacePage.coaching);
                },
                icon: const Icon(Icons.insights_rounded, size: 15),
                label: const Text('Coaching'),
              ),
              OutlinedButton.icon(
                onPressed: _exportCsv,
                icon: const Icon(Icons.file_download_outlined, size: 15),
                label: const Text('Export CSV'),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Expanded(
            child: _tab == 0
                ? SingleChildScrollView(primary: false, child: OutcomesCard(session: s, meName: meName))
                : _TranscriptTab(session: s, initialQuery: widget.searchHint),
          ),
        ],
      ),
    );
  }
}

class _TranscriptTab extends StatefulWidget {
  final MeetingSession session;
  final String initialQuery;

  const _TranscriptTab({required this.session, required this.initialQuery});

  @override
  State<_TranscriptTab> createState() => _TranscriptTabState();
}

class _TranscriptTabState extends State<_TranscriptTab> {
  late final TextEditingController _find = TextEditingController(text: widget.initialQuery);
  late final List<TranscriptBlock> _blocks = TranscriptBlocks.from(widget.session.entries);

  @override
  void dispose() {
    _find.dispose();
    super.dispose();
  }

  String _plainText() => [
        for (final b in _blocks) '${widget.session.nameFor(b.speakerKey)}: ${b.text}',
      ].join('\n\n');

  @override
  Widget build(BuildContext context) {
    final shown = TranscriptBlocks.search(_blocks, _find.text);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _find,
                onChanged: (_) => setState(() {}),
                style: const TextStyle(fontSize: 12.5),
                decoration: InputDecoration(
                  isDense: true,
                  hintText: 'Find in transcript',
                  hintStyle: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                  prefixIcon: const Icon(Icons.search_rounded, size: 16),
                  filled: true,
                  fillColor: AppTheme.cardBackground,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    borderSide: const BorderSide(color: AppTheme.borderSubtle),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    borderSide: const BorderSide(color: AppTheme.borderSubtle),
                  ),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            IconButton(
              tooltip: 'Copy transcript',
              icon: const Icon(Icons.copy_rounded, size: 17),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: _plainText()));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Transcript copied'), duration: Duration(seconds: 2)),
                );
              },
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Expanded(
          child: _blocks.isEmpty
              ? const Text('This meeting has no transcript.', style: TextStyle(fontSize: 12, color: AppTheme.textMuted))
              : shown.isEmpty
                  ? const Text('Nothing matches.', style: TextStyle(fontSize: 12, color: AppTheme.textMuted))
                  : ListView.builder(
                      primary: false,
                      itemCount: shown.length,
                      itemBuilder: (_, i) {
                        final b = shown[i];
                        final color = SpeakerColors.forLabel(b.speakerKey);
                        return Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.md),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                                  const SizedBox(width: 6),
                                  Flexible(
                                    child: Text(
                                      widget.session.nameFor(b.speakerKey),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    DateFormat('HH:mm:ss').format(b.time),
                                    style: const TextStyle(fontSize: 10.5, color: AppTheme.textMuted, fontFamily: 'monospace'),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 3),
                              SelectableText(
                                b.text,
                                style: const TextStyle(fontSize: 13, color: AppTheme.textPrimary, height: 1.5),
                              ),
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
