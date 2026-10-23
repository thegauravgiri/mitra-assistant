import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/design_tokens.dart';
import '../../history/providers/history_providers.dart';
import '../providers/coaching_providers.dart';

/// "Build notes for N older meetings" — runs the meeting digest over every
/// saved meeting that has none, so old conversations join the graph.
class BackfillBar extends ConsumerWidget {
  const BackfillBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final coaching = ref.watch(coachingNotifierProvider);
    final pending = ref
        .watch(historyNotifierProvider)
        .sessions
        .where((s) => s.digest == null && s.entries.isNotEmpty)
        .length;

    if (coaching.backfilling) {
      return Row(
        children: [
          Expanded(
            child: LinearProgressIndicator(
              value: coaching.backfillTotal == 0 ? null : coaching.backfillDone / coaching.backfillTotal,
              minHeight: 4,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            '${coaching.backfillDone} of ${coaching.backfillTotal}',
            style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
          ),
        ],
      );
    }
    if (pending == 0) return const SizedBox.shrink();

    // Stacked, not side by side: this also lives in a 232px sidebar.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FilledButton.tonalIcon(
          onPressed: () => ref.read(coachingNotifierProvider.notifier).backfillDigests(),
          icon: const Icon(Icons.history_edu_rounded, size: 15),
          label: Text(
            'Build notes for $pending older meeting${pending == 1 ? '' : 's'}',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: AppSpacing.xs + 2),
        const Text(
          'One Gemini call per meeting. Adds them to the graph.',
          style: TextStyle(fontSize: 10.5, color: AppTheme.textMuted, height: 1.3),
        ),
      ],
    );
  }
}
