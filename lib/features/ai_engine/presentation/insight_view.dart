import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../documents/presentation/document_chips_bar.dart';
import '../../documents/providers/document_providers.dart';
import '../providers/ai_providers.dart';
import '../domain/models/insight.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/app_text_field.dart';

class InsightView extends ConsumerStatefulWidget {
  final VoidCallback? onOpenSettings;

  const InsightView({super.key, this.onOpenSettings});

  @override
  ConsumerState<InsightView> createState() => _InsightViewState();
}

class _InsightViewState extends ConsumerState<InsightView> {
  final TextEditingController _questionController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  final Set<InsightCategory> _selectedCategories = {};
  String _searchQuery = '';
  bool _isDraggingFile = false;

  @override
  void dispose() {
    _questionController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _submitQuestion() {
    final text = _questionController.text.trim();
    if (text.isNotEmpty) {
      ref.read(aiNotifierProvider.notifier).askQuestion(text);
      _questionController.clear();
    }
  }

  void _toggleCategoryFilter(InsightCategory category) {
    setState(() {
      if (_selectedCategories.contains(category)) {
        _selectedCategories.remove(category);
      } else {
        _selectedCategories.add(category);
      }
    });
  }

  void _resetFilters() {
    setState(() {
      _selectedCategories.clear();
      _searchQuery = '';
      _searchController.clear();
    });
  }

  String get _filterButtonText {
    if (_selectedCategories.isEmpty) return 'All Categories';
    if (_selectedCategories.length == 1) {
      switch (_selectedCategories.first) {
        case InsightCategory.suggestion:
          return '💡 Suggestions';
        case InsightCategory.keyPoint:
          return '📋 Key Points';
        case InsightCategory.question:
          return '❓ Questions';
        case InsightCategory.actionItem:
          return '✅ Action Items';
      }
    }
    return '${_selectedCategories.length} Categories Selected';
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(aiNotifierProvider);

    var filteredInsights = state.insights;
    if (_selectedCategories.isNotEmpty) {
      filteredInsights = filteredInsights.where((i) => _selectedCategories.contains(i.category)).toList();
    }
    if (_searchQuery.trim().isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      filteredInsights = filteredInsights
          .where((i) => i.title.toLowerCase().contains(q) || i.description.toLowerCase().contains(q))
          .toList();
    }

    return DropTarget(
      onDragEntered: (_) => setState(() => _isDraggingFile = true),
      onDragExited: (_) => setState(() => _isDraggingFile = false),
      onDragDone: (details) async {
        setState(() => _isDraggingFile = false);
        final paths = details.files.map((f) => f.path).toList();
        if (paths.isNotEmpty) {
          await ref
              .read(documentNotifierProvider.notifier)
              .addDocumentsFromPaths(paths);
        }
      },
      child: Stack(
        children: [
          Column(
            children: [
              // Header Toolbar (Analyze Now & Actions)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs + 2),
                decoration: BoxDecoration(
                  color: AppTheme.cardBackground.withValues(alpha: 0.3),
                  border: const Border(bottom: BorderSide(color: AppTheme.borderSubtle)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.auto_awesome_rounded, size: 14, color: AppTheme.primaryAccent),
                    const SizedBox(width: AppSpacing.xs + 2),
                    const Text(
                      'AI Copilot Insights',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                    ),
                    if (state.isAnalyzing) ...[
                      const SizedBox(width: AppSpacing.sm),
                      const SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primaryAccent),
                      ),
                    ],
                    const Spacer(),
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: state.isAnalyzing
                            ? null
                            : () {
                                ref.read(aiNotifierProvider.notifier).analyzeCurrentTranscript(force: true);
                              },
                        child: AnimatedContainer(
                          duration: AppDuration.fast,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: state.isAnalyzing
                                ? AppTheme.primaryAccent.withValues(alpha: 0.1)
                                : AppTheme.primaryAccent.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: AppTheme.primaryAccent.withValues(alpha: state.isAnalyzing ? 0.3 : 0.7),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.auto_awesome_rounded,
                                size: 12,
                                color: state.isAnalyzing
                                    ? AppTheme.textMuted
                                    : AppTheme.primaryAccent,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                state.isAnalyzing ? 'Analyzing...' : 'Analyze Now',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: state.isAnalyzing
                                      ? AppTheme.textMuted
                                      : AppTheme.textPrimary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    if (state.insights.isNotEmpty) ...[
                      const SizedBox(width: AppSpacing.xs + 2),
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

              // Filter Bar (Multi-Select Category Dropdown + Search Input Field)
              if (state.insights.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.backgroundDark.withValues(alpha: 0.5),
                    border: const Border(bottom: BorderSide(color: AppTheme.borderSubtle, width: 1)),
                  ),
                  child: Row(
                    children: [
                      // Multi-Select Category Dropdown Button
                      PopupMenuButton<InsightCategory?>(
                        tooltip: 'Filter by Categories',
                        offset: const Offset(0, 32),
                        color: AppTheme.cardBackground,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          side: const BorderSide(color: AppTheme.borderSubtle),
                        ),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppTheme.cardBackground,
                            borderRadius: BorderRadius.circular(AppRadius.sm),
                            border: Border.all(
                              color: _selectedCategories.isNotEmpty
                                  ? AppTheme.primaryAccent
                                  : AppTheme.borderSubtle,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.filter_list_rounded,
                                size: 13,
                                color: _selectedCategories.isNotEmpty
                                    ? AppTheme.primaryAccent
                                    : AppTheme.textMuted,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                _filterButtonText,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: _selectedCategories.isNotEmpty
                                      ? AppTheme.primaryAccent
                                      : AppTheme.textPrimary,
                                ),
                              ),
                              const SizedBox(width: 2),
                              const Icon(Icons.arrow_drop_down_rounded, size: 14, color: AppTheme.textMuted),
                            ],
                          ),
                        ),
                        itemBuilder: (context) {
                          return [
                            PopupMenuItem<InsightCategory?>(
                              value: null,
                              onTap: () {
                                setState(() => _selectedCategories.clear());
                              },
                              child: Row(
                                children: [
                                  Icon(
                                    _selectedCategories.isEmpty
                                        ? Icons.check_box_rounded
                                        : Icons.check_box_outline_blank_rounded,
                                    size: 15,
                                    color: _selectedCategories.isEmpty
                                        ? AppTheme.primaryAccent
                                        : AppTheme.textMuted,
                                  ),
                                  const SizedBox(width: 8),
                                  const Text('All Categories', style: TextStyle(fontSize: 11, color: AppTheme.textPrimary, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                            const PopupMenuDivider(height: 1),
                            ...InsightCategory.values.map((cat) {
                              final isSelected = _selectedCategories.contains(cat);
                              String title;
                              switch (cat) {
                                case InsightCategory.suggestion:
                                  title = '💡 Suggestions';
                                  break;
                                case InsightCategory.keyPoint:
                                  title = '📋 Key Points';
                                  break;
                                case InsightCategory.question:
                                  title = '❓ Questions';
                                  break;
                                case InsightCategory.actionItem:
                                  title = '✅ Action Items';
                                  break;
                              }

                              return PopupMenuItem<InsightCategory?>(
                                value: cat,
                                onTap: () {
                                  _toggleCategoryFilter(cat);
                                },
                                child: Row(
                                  children: [
                                    Icon(
                                      isSelected
                                          ? Icons.check_box_rounded
                                          : Icons.check_box_outline_blank_rounded,
                                      size: 15,
                                      color: isSelected ? AppTheme.primaryAccent : AppTheme.textMuted,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      title,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                        color: AppTheme.textPrimary,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }),
                          ];
                        },
                      ),

                      const SizedBox(width: AppSpacing.sm),

                      // Search Input Field
                      Expanded(
                        child: SizedBox(
                          height: 28,
                          child: TextField(
                            controller: _searchController,
                            style: const TextStyle(fontSize: 11, color: AppTheme.textPrimary),
                            decoration: InputDecoration(
                              hintText: 'Search insights...',
                              hintStyle: const TextStyle(fontSize: 10, color: AppTheme.textMuted),
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                              filled: true,
                              fillColor: AppTheme.cardBackground,
                              prefixIcon: const Icon(Icons.search_rounded, size: 13, color: AppTheme.textMuted),
                              prefixIconConstraints: const BoxConstraints(minWidth: 24, minHeight: 0),
                              suffixIcon: _searchQuery.isNotEmpty
                                  ? GestureDetector(
                                      onTap: () {
                                        _searchController.clear();
                                        setState(() => _searchQuery = '');
                                      },
                                      child: const Icon(Icons.close_rounded, size: 13, color: AppTheme.textMuted),
                                    )
                                  : null,
                              suffixIconConstraints: const BoxConstraints(minWidth: 20, minHeight: 0),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(AppRadius.sm),
                                borderSide: const BorderSide(color: AppTheme.borderSubtle),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(AppRadius.sm),
                                borderSide: const BorderSide(color: AppTheme.borderSubtle),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(AppRadius.sm),
                                borderSide: const BorderSide(color: AppTheme.primaryAccent),
                              ),
                            ),
                            onChanged: (val) {
                              setState(() {
                                _searchQuery = val;
                              });
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              // Error Banner Display
              if (state.error != null)
                Container(
                  margin: const EdgeInsets.all(AppSpacing.sm),
                  padding: const EdgeInsets.all(AppSpacing.sm + 2),
                  decoration: BoxDecoration(
                    color: AppTheme.panicAccent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(color: AppTheme.panicAccent.withValues(alpha: 0.5)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded, color: AppTheme.panicAccent, size: 18),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          state.error!,
                          style: const TextStyle(color: AppTheme.textPrimary, fontSize: 11, fontWeight: FontWeight.w500),
                        ),
                      ),
                      if (state.error!.contains('Settings'))
                        TextButton(
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
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

              // Main Content Area / Empty State / Filtered List
              Expanded(
                child: state.isAnalyzing && state.insights.isEmpty
                    ? const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(color: AppTheme.primaryAccent, strokeWidth: 2),
                            SizedBox(height: AppSpacing.md),
                            Text(
                              'Generating AI Insights...',
                              style: TextStyle(color: AppTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      )
                    : state.insights.isEmpty
                        ? EmptyStateWidget(
                            icon: Icons.auto_awesome_outlined,
                            title: 'AI Copilot Ready',
                            description: 'Contextual talking points, key items, and follow-up questions will automatically update as meeting transcript accumulates.',
                            actionButton: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppTheme.primaryAccent,
                                side: const BorderSide(color: AppTheme.primaryAccent),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                              ),
                              icon: const Icon(Icons.play_arrow_rounded, size: 16),
                              label: const Text('Run Manual Analysis', style: TextStyle(fontSize: 12)),
                              onPressed: () {
                                ref.read(aiNotifierProvider.notifier).analyzeCurrentTranscript(force: true);
                              },
                            ),
                          )
                        : filteredInsights.isEmpty
                            ? EmptyStateWidget(
                                icon: Icons.filter_alt_off_rounded,
                                title: 'No Matching Insights',
                                description: 'No insights match your active category filter or search query.',
                                actionButton: OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: AppTheme.primaryAccent,
                                    side: const BorderSide(color: AppTheme.borderSubtle),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                                  ),
                                  icon: const Icon(Icons.clear_all_rounded, size: 16),
                                  label: const Text('Reset Filters', style: TextStyle(fontSize: 12)),
                                  onPressed: _resetFilters,
                                ),
                              )
                            : ListView.builder(
                                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                                itemCount: filteredInsights.length,
                                itemBuilder: (context, index) {
                                  final insight = filteredInsights[index];
                                  return _InsightCard(insight: insight);
                                },
                              ),
              ),

              // Uploaded Document Chips Bar
              const DocumentChipsBar(),

              // Bottom Custom Prompt Input Field
              Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: const BoxDecoration(
                  color: AppTheme.cardBackground,
                  border: Border(top: BorderSide(color: AppTheme.borderSubtle, width: 1)),
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.attach_file_rounded, size: 18, color: AppTheme.textMuted),
                      tooltip: 'Attach Documents (PDF, DOCX, TXT, MD)',
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      constraints: const BoxConstraints(),
                      onPressed: () {
                        ref
                            .read(documentNotifierProvider.notifier)
                            .pickAndAddDocuments();
                      },
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(
                      child: AppTextField(
                        controller: _questionController,
                        hintText: 'Ask AI Copilot (e.g. "What should I say next?")...',
                        onSubmitted: (_) => _submitQuestion(),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs + 2),
                    IconButton(
                      style: IconButton.styleFrom(
                        backgroundColor: AppTheme.primaryAccent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.all(AppSpacing.sm + 1),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
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
          ),

          // File Drag & Drop Visual Overlay
          if (_isDraggingFile)
            Positioned.fill(
              child: Container(
                color: AppTheme.primaryAccent.withValues(alpha: 0.2),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: AppTheme.cardBackground,
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                      border: Border.all(color: AppTheme.primaryAccent, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primaryAccent.withValues(alpha: 0.3),
                          blurRadius: 20,
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.upload_file_rounded, size: 48, color: AppTheme.primaryAccent),
                        SizedBox(height: 12),
                        Text(
                          'Drop documents here to attach',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Supports PDF, DOCX, TXT, MD',
                          style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
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
        return AppTheme.cyanAccent;
    }
  }

  String _getCategoryLabel(InsightCategory cat) {
    switch (cat) {
      case InsightCategory.suggestion:
        return 'SUGGESTION';
      case InsightCategory.keyPoint:
        return 'KEY POINT';
      case InsightCategory.question:
        return 'QUESTION';
      case InsightCategory.actionItem:
        return 'ACTION ITEM';
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
    final label = _getCategoryLabel(insight.category);

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm + 2),
      decoration: BoxDecoration(
        color: AppTheme.cardBackground,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppTheme.borderSubtle),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Container(
          decoration: BoxDecoration(
            border: Border(left: BorderSide(color: color, width: 4)),
          ),
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, size: 15, color: color),
                  const SizedBox(width: AppSpacing.xs),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(AppRadius.sm - 2),
                    ),
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: color,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs + 2),
                  Expanded(
                    child: Text(
                      insight.title,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: color,
                        letterSpacing: -0.1,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy_rounded, size: 14, color: AppTheme.textMuted),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    tooltip: 'Copy to Clipboard',
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: '${insight.title}: ${insight.description}'));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Copied insight to clipboard!'),
                          duration: Duration(seconds: 1),
                          backgroundColor: AppTheme.secondaryAccent,
                        ),
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs + 2),
              Text(
                insight.description,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppTheme.textPrimary,
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
