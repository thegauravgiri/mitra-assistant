import 'package:flutter/material.dart';
import 'control_bar.dart';
import '../../transcription/presentation/transcript_view.dart';
import '../../ai_engine/presentation/insight_view.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../core/widgets/animated_tab_bar.dart';

/// Zen window: just the live meeting (insights + transcript). Everything else
/// lives in the Workspace.
class ExpandedModeView extends StatefulWidget {
  final VoidCallback onCollapse;
  final VoidCallback onOpenWorkspace;
  final VoidCallback onOpenSettings;

  const ExpandedModeView({
    super.key,
    required this.onCollapse,
    required this.onOpenWorkspace,
    required this.onOpenSettings,
  });

  @override
  State<ExpandedModeView> createState() => _ExpandedModeViewState();
}

class _ExpandedModeViewState extends State<ExpandedModeView> {
  int _activeTab = 0;

  static const List<TabItemData> _tabItems = [
    TabItemData(title: 'AI Copilot', icon: Icons.auto_awesome_rounded),
    TabItemData(title: 'Transcript', icon: Icons.subtitles_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.backgroundDark,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppTheme.borderGlow.withValues(alpha: 0.4), width: 1.5),
        boxShadow: AppShadows.medium,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Column(
          children: [
            ControlBar(
              isCompact: false,
              onToggleCompact: widget.onCollapse,
              onOpenWorkspace: widget.onOpenWorkspace,
              onNeedSettings: widget.onOpenSettings,
            ),
            AnimatedTabBar(
              tabs: _tabItems,
              activeIndex: _activeTab,
              onTabChanged: (idx) => setState(() => _activeTab = idx),
            ),
            // IndexedStack preserves tab states and scroll positions
            Expanded(
              child: IndexedStack(
                index: _activeTab,
                children: [
                  InsightView(onOpenSettings: widget.onOpenSettings),
                  const TranscriptView(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
