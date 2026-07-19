import 'package:flutter/material.dart';
import 'control_bar.dart';
import '../../transcription/presentation/transcript_view.dart';
import '../../ai_engine/presentation/insight_view.dart';
import '../../settings/presentation/settings_view.dart';
import '../../history/presentation/history_view.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../core/widgets/animated_tab_bar.dart';

class ExpandedModeView extends StatefulWidget {
  final VoidCallback onCollapse;

  const ExpandedModeView({super.key, required this.onCollapse});

  @override
  State<ExpandedModeView> createState() => _ExpandedModeViewState();
}

class _ExpandedModeViewState extends State<ExpandedModeView> {
  int _activeTab = 0; // Default to AI Copilot (Index 0)

  static const List<TabItemData> _tabItems = [
    TabItemData(title: 'AI Copilot', icon: Icons.auto_awesome_rounded),
    TabItemData(title: 'Transcript', icon: Icons.subtitles_rounded),
    TabItemData(title: 'History', icon: Icons.history_rounded),
    TabItemData(title: 'Settings', icon: Icons.tune_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.backgroundDark,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: AppTheme.borderGlow.withValues(alpha: 0.4),
          width: 1.5,
        ),
        boxShadow: AppShadows.medium,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Column(
          children: [
            // Top Control Bar
            ControlBar(
              activeTab: _activeTab,
              onTabChanged: (idx) => setState(() => _activeTab = idx),
              isCompact: false,
              onToggleCompact: widget.onCollapse,
            ),

            // Tab Navigation Switcher
            AnimatedTabBar(
              tabs: _tabItems,
              activeIndex: _activeTab,
              onTabChanged: (idx) => setState(() => _activeTab = idx),
            ),

            // Main Tab View Content with Fade Transition
            Expanded(
              child: AnimatedSwitcher(
                duration: AppDuration.fast,
                child: KeyedSubtree(
                  key: ValueKey<int>(_activeTab),
                  child: IndexedStack(
                    index: _activeTab,
                    children: [
                      InsightView(onOpenSettings: () => setState(() => _activeTab = 3)),
                      const TranscriptView(),
                      const HistoryView(),
                      const SettingsView(),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
