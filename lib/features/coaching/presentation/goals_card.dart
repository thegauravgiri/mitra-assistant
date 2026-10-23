import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/design_tokens.dart';
import '../../settings/providers/settings_providers.dart';
import '../data/report_view_model.dart';
import '../../../core/theme/graph_palette.dart';
import '../domain/models/goal.dart';
import 'section_card.dart';

class GoalsCard extends ConsumerWidget {
  final ReportViewModel vm;

  const GoalsCard({super.key, required this.vm});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goals = ref.watch(settingsNotifierProvider).goals;

    return SectionCard(
      icon: Icons.flag_rounded,
      title: 'My goals',
      trailing: TextButton(
        onPressed: () => showDialog(context: context, builder: (_) => const _GoalsEditor()),
        child: Text(goals.isEmpty ? 'Set goals' : 'Edit'),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (goals.isEmpty)
            const Hint('Pick up to three things to work on. Each meeting is checked against them.'),
          for (final r in vm.goals)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Icon(
                    r.met == null
                        ? StatusStyle.unknown.icon
                        : (r.met! ? StatusStyle.good.icon : StatusStyle.watch.icon),
                    size: 15,
                    color: r.met == null
                        ? StatusStyle.unknown.color
                        : (r.met! ? StatusStyle.good.color : StatusStyle.watch.color),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(r.goal.description, style: const TextStyle(fontSize: 12, color: AppTheme.textPrimary)),
                  ),
                  Text(r.valueText, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                ],
              ),
            ),
          if (goals.isNotEmpty && vm.me == null)
            const Hint('Pick which speaker you are to see how this meeting went.'),
        ],
      ),
    );
  }
}

class _GoalsEditor extends ConsumerStatefulWidget {
  const _GoalsEditor();

  @override
  ConsumerState<_GoalsEditor> createState() => _GoalsEditorState();
}

class _GoalsEditorState extends ConsumerState<_GoalsEditor> {
  late final Map<GoalType, TextEditingController> _targets;
  late final Set<GoalType> _selected;

  @override
  void initState() {
    super.initState();
    final goals = ref.read(settingsNotifierProvider).goals;
    _selected = {for (final g in goals) g.type};
    _targets = {
      for (final t in GoalType.values)
        t: TextEditingController(
          text: (goals.where((g) => g.type == t).map((g) => g.target).firstOrNull ?? Goal.defaultTarget(t))
              .toStringAsFixed(0),
        ),
    };
  }

  @override
  void dispose() {
    for (final c in _targets.values) {
      c.dispose();
    }
    super.dispose();
  }

  String _unit(GoalType t) {
    switch (t) {
      case GoalType.interruptions:
        return 'max per meeting';
      case GoalType.monologue:
        return 'seconds';
      case GoalType.questions:
        return 'min per meeting';
      case GoalType.fillers:
        return 'max per minute';
      case GoalType.talkShare:
        return 'points from fair share';
      case GoalType.pace:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppTheme.backgroundPureDark,
      title: Text(
        'My goals (up to ${AppConstants.maxGoals})',
        style: const TextStyle(fontSize: 14, color: AppTheme.textPrimary),
      ),
      content: SizedBox(
        width: 360,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final t in GoalType.values)
                CheckboxListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  value: _selected.contains(t),
                  onChanged: (v) => setState(() {
                    if (v == true && _selected.length < AppConstants.maxGoals) {
                      _selected.add(t);
                    } else if (v == false) {
                      _selected.remove(t);
                    }
                  }),
                  title: Text(Goal.label(t), style: const TextStyle(fontSize: 12)),
                  subtitle: t == GoalType.pace
                      ? const Text('Typical conversational range', style: TextStyle(fontSize: 10))
                      : Row(
                          children: [
                            SizedBox(
                              width: 56,
                              child: TextField(
                                controller: _targets[t],
                                keyboardType: TextInputType.number,
                                style: const TextStyle(fontSize: 12),
                                decoration: const InputDecoration(isDense: true),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(_unit(t), style: const TextStyle(fontSize: 10)),
                          ],
                        ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        FilledButton(
          onPressed: () async {
            final goals = [
              for (final t in GoalType.values)
                if (_selected.contains(t))
                  Goal(t, double.tryParse(_targets[t]!.text.trim()) ?? Goal.defaultTarget(t)),
            ];
            await ref.read(settingsNotifierProvider.notifier).updateGoals(goals);
            if (context.mounted) Navigator.of(context).pop();
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}
