import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../core/utils/text_similarity.dart';
import '../../history/domain/models/meeting_session.dart';
import '../domain/models/meeting_digest.dart';
import '../providers/coaching_providers.dart';
import 'section_card.dart';

/// The notes for one meeting: overview, what was said per topic, decisions with
/// their reasons, action items (yours highlighted), questions left open, risks
/// and key facts. Lives in History.
class OutcomesCard extends ConsumerWidget {
  final MeetingSession session;
  final String? meName;

  const OutcomesCard({super.key, required this.session, required this.meName});

  bool _isMine(String? owner) =>
      owner != null && meName != null && TextSimilarity.normalize(owner) == TextSimilarity.normalize(meName!);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final coaching = ref.watch(coachingNotifierProvider);
    final busy = coaching.digesting.contains(session.id);
    final error = coaching.errors[session.id];
    final digest = session.digest;

    return SectionCard(
      icon: Icons.fact_check_rounded,
      title: 'Meeting notes',
      trailing: TextButton.icon(
        onPressed: busy ? null : () => ref.read(coachingNotifierProvider.notifier).generateDigest(session),
        icon: busy
            ? const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2))
            : const Icon(Icons.refresh_rounded, size: 14),
        label: Text(digest == null ? 'Generate notes' : 'Regenerate'),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (busy)
            const Hint('Writing the notes. Long meetings are read in parts, so this can take a minute…'),
          if (error != null)
            Text(error, style: const TextStyle(fontSize: 11.5, color: AppTheme.panicAccent)),
          if (digest == null && !busy)
            const Hint('Notes (overview, topics, decisions, action items, open questions) appear here once generated.'),
          if (digest != null) ..._body(digest),
        ],
      ),
    );
  }

  List<Widget> _body(MeetingDigest d) => [
        if (d.summary.isNotEmpty)
          Text(d.summary, style: const TextStyle(fontSize: 12.5, color: AppTheme.textPrimary, height: 1.55)),
        if (d.topics.isNotEmpty)
          _section('What was discussed', [
            for (final t in d.topics) _topic(t),
          ]),
        if (d.decisions.isNotEmpty)
          _section('Decisions', [
            for (final x in d.decisions) _item(x.text, note: x.rationale, quote: x.evidence),
          ]),
        if (d.actionItems.isNotEmpty)
          _section('Action items', [
            for (final a in d.actionItems)
              _item(
                '${a.owner == null ? '' : '${a.owner}: '}${a.task}',
                note: a.due == null ? null : 'Due: ${a.due}',
                quote: a.evidence,
                highlight: _isMine(a.owner),
              ),
          ]),
        if (d.openQuestions.isNotEmpty)
          _section('Left unanswered', [
            for (final q in d.openQuestions)
              _item('${q.asker == null ? '' : '${q.asker} asked: '}${q.question}', note: q.context),
          ]),
        if (d.risks.isNotEmpty) _section('Risks and concerns', [for (final r in d.risks) _item(r)]),
        if (d.keyFacts.isNotEmpty) _section('Key facts', [for (final f in d.keyFacts) _item(f)]),
      ];

  Widget _section(String title, List<Widget> children) => Padding(
        padding: const EdgeInsets.only(top: AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title.toUpperCase(),
              style: const TextStyle(fontSize: 10.5, letterSpacing: 0.8, fontWeight: FontWeight.w700, color: AppTheme.textMuted),
            ),
            const SizedBox(height: AppSpacing.sm),
            ...children,
          ],
        ),
      );

  Widget _topic(DigestTopic t) => Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Flexible(
                  child: Text(
                    t.name,
                    style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                  ),
                ),
                if (t.raisedBy != null) ...[
                  const SizedBox(width: 8),
                  Text('raised by ${t.raisedBy}', style: const TextStyle(fontSize: 10.5, color: AppTheme.textMuted)),
                ],
              ],
            ),
            if (t.summary != null)
              Padding(
                padding: const EdgeInsets.only(top: 3),
                child: Text(t.summary!, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary, height: 1.5)),
              ),
          ],
        ),
      );

  Widget _item(String text, {String? note, String? quote, bool highlight = false}) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('• ', style: TextStyle(color: highlight ? AppTheme.primaryAccent : AppTheme.textMuted)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    text,
                    style: TextStyle(
                      fontSize: 12.5,
                      height: 1.45,
                      fontWeight: highlight ? FontWeight.w700 : FontWeight.w500,
                      color: highlight ? AppTheme.primaryAccent : AppTheme.textPrimary,
                    ),
                  ),
                  if (note != null)
                    Text(note, style: const TextStyle(fontSize: 11.5, color: AppTheme.textSecondary, height: 1.4)),
                  if (quote != null)
                    Text(
                      '“$quote”',
                      style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: AppTheme.textMuted, height: 1.4),
                    ),
                ],
              ),
            ),
          ],
        ),
      );
}
