import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../history/domain/models/meeting_session.dart';
import '../../../core/theme/graph_palette.dart';
import '../domain/models/coaching_feedback.dart';
import 'section_card.dart';
import '../providers/coaching_providers.dart';

/// Strengths and improvements for "me", with quotes from the transcript.
class FeedbackCard extends ConsumerWidget {
  final MeetingSession session;

  const FeedbackCard({super.key, required this.session});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final coaching = ref.watch(coachingNotifierProvider);
    final busy = coaching.generating.contains(session.id);
    final error = coaching.errors[session.id];
    final feedback = session.feedback;

    return SectionCard(
      icon: Icons.tips_and_updates_rounded,
      title: 'Your coaching',
      trailing: session.meSpeakerKey == null
          ? null
          : TextButton.icon(
              onPressed: busy ? null : () => ref.read(coachingNotifierProvider.notifier).generateCoaching(session),
              icon: busy
                  ? const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.auto_awesome_rounded, size: 14),
              label: Text(feedback == null ? 'Generate' : 'Regenerate'),
            ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (session.meSpeakerKey == null)
            const Hint('Choose which speaker you are above to get personalised coaching.'),
          if (busy && feedback == null)
            const Hint('Writing your coaching…'),
          if (error != null)
            Text(error, style: const TextStyle(fontSize: 11.5, color: AppTheme.panicAccent)),
          if (feedback != null) ...[
            for (final s in feedback.strengths)
              _Item(item: s, icon: StatusStyle.good.icon, color: StatusStyle.good.color),
            for (final s in feedback.improvements)
              _Item(item: s, icon: Icons.trending_up_rounded, color: StatusStyle.ok.color),
            for (final n in feedback.goalNotes)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.flag_rounded, size: 14, color: AppTheme.primaryAccent),
                    const SizedBox(width: 8),
                    Expanded(child: Text(n, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary))),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _Item extends StatelessWidget {
  final FeedbackItem item;
  final IconData icon;
  final Color color;

  const _Item({required this.item, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
                ),
                if (item.evidence != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      '“${item.evidence}”',
                      style: const TextStyle(fontSize: 11.5, fontStyle: FontStyle.italic, color: AppTheme.textSecondary),
                    ),
                  ),
                if (item.tip != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      'Try: ${item.tip}',
                      style: const TextStyle(fontSize: 11.5, color: AppTheme.textPrimary, height: 1.4),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
