import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/ai_providers.dart';
import '../domain/models/insight.dart';
import '../../../core/theme/app_theme.dart';

class InsightView extends ConsumerStatefulWidget {
  final VoidCallback? onOpenSettings;

  const InsightView({super.key, this.onOpenSettings});

  @override
  ConsumerState<InsightView> createState() => _InsightViewState();
}

class _InsightViewState extends ConsumerState<InsightView> {
  final TextEditingController _questionController = TextEditingController();

  @override
  void dispose() {
    _questionController.dispose();
    super.dispose();
  }

  void _submitQuestion() {
    final text = _questionController.text.trim();
    if (text.isNotEmpty) {
      ref.read(aiNotifierProvider.notifier).askQuestion(text);
      _questionController.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(aiNotifierProvider);

    return Column(
      children: [
        // Header Toolbar (Analyze Now & Actions)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          color: AppTheme.cardBackground.withValues(alpha: 0.3),
          child: Row(
            children: [
              const Icon(Icons.auto_awesome_rounded, size: 14, color: AppTheme.primaryAccent),
              const SizedBox(width: 6),
              const Text(
                'AI Insights',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
              ),
              if (state.isAnalyzing) ...[
                const SizedBox(width: 8),
                const SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primaryAccent),
                ),
              ],
              const Spacer(),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryAccent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                ),
                icon: const Icon(Icons.refresh_rounded, size: 12),
                label: const Text('Analyze Now', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                onPressed: state.isAnalyzing
                    ? null
                    : () {
                        ref.read(aiNotifierProvider.notifier).analyzeCurrentTranscript(force: true);
                      },
              ),
              if (state.insights.isNotEmpty) ...[
                const SizedBox(width: 6),
                IconButton(
                  icon: const Icon(Icons.delete_sweep_rounded, size: 16, color: AppTheme.textMuted),
                  tooltip: 'Clear Insights',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () {
                    ref.read(aiNotifierProvider.notifier).clearInsights();
                  },
                ),
              ],
            ],
          ),
        ),

        // Error Banner Display
        if (state.error != null)
          Container(
            margin: const EdgeInsets.all(10),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.panicAccent.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.panicAccent.withValues(alpha: 0.5)),
            ),
            child: Row(
              children: [
                const Icon(Icons.warning_amber_rounded, color: AppTheme.panicAccent, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    state.error!,
                    style: const TextStyle(color: AppTheme.textPrimary, fontSize: 11, fontWeight: FontWeight.w500),
                  ),
                ),
                if (state.error!.contains('Settings'))
                  TextButton(
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    onPressed: widget.onOpenSettings,
                    child: const Text('Settings', style: TextStyle(fontSize: 11, color: AppTheme.primaryAccent, fontWeight: FontWeight.bold)),
                  )
                else
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 14, color: AppTheme.textMuted),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () {
                      ref.read(aiNotifierProvider.notifier).clearError();
                    },
                  ),
              ],
            ),
          ),

        // Main List Content / Empty State
        Expanded(
          child: state.isAnalyzing && state.insights.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(color: AppTheme.primaryAccent, strokeWidth: 2),
                      SizedBox(height: 12),
                      Text(
                        'Generating AI Insights...',
                        style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                      ),
                    ],
                  ),
                )
              : state.insights.isEmpty
                  ? Center(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.auto_awesome_outlined, color: AppTheme.primaryAccent, size: 40),
                            const SizedBox(height: 12),
                            const Text(
                              'AI Copilot Ready',
                              style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'Contextual talking points, key items, and follow-up questions will update as meeting transcript accumulates.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: AppTheme.textMuted, fontSize: 11, height: 1.4),
                            ),
                            const SizedBox(height: 16),
                            OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppTheme.primaryAccent,
                                side: const BorderSide(color: AppTheme.primaryAccent),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              icon: const Icon(Icons.play_arrow_rounded, size: 16),
                              label: const Text('Run Manual Analysis', style: TextStyle(fontSize: 12)),
                              onPressed: () {
                                ref.read(aiNotifierProvider.notifier).analyzeCurrentTranscript(force: true);
                              },
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      itemCount: state.insights.length,
                      itemBuilder: (context, index) {
                        final insight = state.insights[index];
                        return _InsightCard(insight: insight);
                      },
                    ),
        ),

        // Bottom Custom Prompt Input Field
        Container(
          padding: const EdgeInsets.all(8.0),
          decoration: const BoxDecoration(
            color: AppTheme.cardBackground,
            border: Border(top: BorderSide(color: AppTheme.borderSubtle, width: 1)),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _questionController,
                  style: const TextStyle(fontSize: 12, color: AppTheme.textPrimary),
                  decoration: InputDecoration(
                    hintText: 'Ask AI Copilot (e.g. "What should I say next?")...',
                    hintStyle: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    filled: true,
                    fillColor: AppTheme.backgroundDark,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: AppTheme.borderSubtle),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: AppTheme.primaryAccent),
                    ),
                  ),
                  onSubmitted: (_) => _submitQuestion(),
                ),
              ),
              const SizedBox(width: 6),
              IconButton(
                style: IconButton.styleFrom(
                  backgroundColor: AppTheme.primaryAccent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.all(8),
                ),
                constraints: const BoxConstraints(),
                icon: const Icon(Icons.send_rounded, size: 14),
                tooltip: 'Send Question',
                onPressed: _submitQuestion,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _InsightCard extends StatelessWidget {
  final Insight insight;
  const _InsightCard({required this.insight});

  Color _getCategoryColor(InsightCategory cat) {
    switch (cat) {
      case InsightCategory.suggestion:
        return AppTheme.primaryAccent;
      case InsightCategory.keyPoint:
        return AppTheme.secondaryAccent;
      case InsightCategory.question:
        return AppTheme.warningAccent;
      case InsightCategory.actionItem:
        return Colors.cyanAccent;
    }
  }

  IconData _getCategoryIcon(InsightCategory cat) {
    switch (cat) {
      case InsightCategory.suggestion:
        return Icons.lightbulb_outline_rounded;
      case InsightCategory.keyPoint:
        return Icons.push_pin_outlined;
      case InsightCategory.question:
        return Icons.help_outline_rounded;
      case InsightCategory.actionItem:
        return Icons.check_circle_outline_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _getCategoryColor(insight.category);
    final icon = _getCategoryIcon(insight.category);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 16, color: color),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    insight.title,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.copy_rounded, size: 14, color: AppTheme.textMuted),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: '${insight.title}: ${insight.description}'));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Copied to clipboard!'), duration: Duration(seconds: 1)),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              insight.description,
              style: const TextStyle(
                fontSize: 12,
                color: AppTheme.textPrimary,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
