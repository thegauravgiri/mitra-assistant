import 'package:flutter/material.dart';
import 'control_bar.dart';
import '../../transcription/presentation/transcript_view.dart';
import '../../ai_engine/presentation/insight_view.dart';
import '../../settings/presentation/settings_view.dart';
import '../../history/presentation/history_view.dart';
import '../../../core/theme/app_theme.dart';

class ExpandedModeView extends StatefulWidget {
  final VoidCallback onCollapse;

  const ExpandedModeView({super.key, required this.onCollapse});

  @override
  State<ExpandedModeView> createState() => _ExpandedModeViewState();
}

class _ExpandedModeViewState extends State<ExpandedModeView> {
  int _activeTab = 1; // Default to AI Copilot

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.backgroundDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderSubtle, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
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
          Container(
            color: AppTheme.cardBackground.withValues(alpha: 0.5),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Row(
              children: [
                _TabButton(
                  title: 'AI Copilot',
                  icon: Icons.auto_awesome_rounded,
                  isActive: _activeTab == 1,
                  onTap: () => setState(() => _activeTab = 1),
                ),
                const SizedBox(width: 4),
                _TabButton(
                  title: 'Transcript',
                  icon: Icons.subtitles_rounded,
                  isActive: _activeTab == 0,
                  onTap: () => setState(() => _activeTab = 0),
                ),
                const SizedBox(width: 4),
                _TabButton(
                  title: 'History',
                  icon: Icons.history_rounded,
                  isActive: _activeTab == 3,
                  onTap: () => setState(() => _activeTab = 3),
                ),
                const SizedBox(width: 4),
                _TabButton(
                  title: 'Settings',
                  icon: Icons.tune_rounded,
                  isActive: _activeTab == 2,
                  onTap: () => setState(() => _activeTab = 2),
                ),
              ],
            ),
          ),

          // Main Tab View Content
          Expanded(
            child: IndexedStack(
              index: _activeTab,
              children: [
                const TranscriptView(),
                InsightView(onOpenSettings: () => setState(() => _activeTab = 2)),
                const SettingsView(),
                const HistoryView(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  final String title;
  final IconData icon;
  final bool isActive;
  final VoidCallback onTap;

  const _TabButton({
    required this.title,
    required this.icon,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: isActive ? AppTheme.primaryAccent.withValues(alpha: 0.2) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isActive ? AppTheme.primaryAccent : Colors.transparent,
              width: 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 14, color: isActive ? AppTheme.primaryAccent : AppTheme.textMuted),
              const SizedBox(width: 4),
              Text(
                title,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                  color: isActive ? AppTheme.textPrimary : AppTheme.textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
