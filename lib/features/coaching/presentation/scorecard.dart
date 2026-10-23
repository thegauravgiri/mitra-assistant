import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../core/theme/graph_palette.dart';
import '../data/indicator_evaluator.dart';
import 'section_card.dart';
import '../data/report_view_model.dart';

StatusStyle styleOf(IndicatorStatus s) {
  switch (s) {
    case IndicatorStatus.good:
      return StatusStyle.good;
    case IndicatorStatus.ok:
      return StatusStyle.ok;
    case IndicatorStatus.watch:
      return StatusStyle.watch;
    case IndicatorStatus.unknown:
      return StatusStyle.unknown;
  }
}

/// Indicator tiles in an even grid, grouped into Delivery and Listening.
class Scorecard extends StatelessWidget {
  final ReportViewModel vm;

  const Scorecard({super.key, required this.vm});

  @override
  Widget build(BuildContext context) {
    if (vm.indicators.isEmpty) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, box) {
        const gap = AppSpacing.sm + 2;
        final cols = (box.maxWidth / 190).floor().clamp(2, 4);
        final tileW = (box.maxWidth - gap * (cols - 1)) / cols;

        Widget group(String title, IndicatorGroup g) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: Text(
                    title.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 10.5,
                      letterSpacing: 0.8,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textMuted,
                    ),
                  ),
                ),
                Wrap(
                  spacing: gap,
                  runSpacing: gap,
                  children: [
                    for (final i in vm.indicators.where((i) => i.group == g))
                      SizedBox(width: tileW, child: _Tile(indicator: i, baseline: vm.baselines[i.id])),
                  ],
                ),
              ],
            );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            group('Delivery', IndicatorGroup.delivery),
            const SizedBox(height: AppSpacing.lg),
            group('Listening & inclusion', IndicatorGroup.listening),
            const SizedBox(height: AppSpacing.sm),
            const Hint('Ranges are rules of thumb, not norms. Interruptions are estimated from one mixed audio stream.'),
          ],
        );
      },
    );
  }
}

class _Tile extends StatelessWidget {
  final Indicator indicator;
  final double? baseline;

  const _Tile({required this.indicator, required this.baseline});

  String? get _delta {
    final v = indicator.value;
    if (v == null || baseline == null || indicator.id == 'talkShare') return null;
    final d = v - baseline!;
    if (d.abs() < 0.05) return 'same as your average';
    return '${d > 0 ? '▲' : '▼'} ${d.abs().toStringAsFixed(1)} vs your average';
  }

  @override
  Widget build(BuildContext context) {
    final st = styleOf(indicator.status);
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Container(
        color: AppTheme.cardBackground,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: 3, color: st.color),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md - 2, AppSpacing.md, AppSpacing.md - 2),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        indicator.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 11.5, color: AppTheme.textSecondary),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        indicator.display,
                        style: const TextStyle(
                          fontSize: 21,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary,
                          height: 1.15,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(st.icon, size: 12, color: st.color),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              st.word,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: st.color),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        indicator.rangeText,
                        style: const TextStyle(fontSize: 10.5, color: AppTheme.textMuted, height: 1.3),
                      ),
                      if (_delta != null)
                        Text(_delta!, style: const TextStyle(fontSize: 10.5, color: AppTheme.textMuted, height: 1.3)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
