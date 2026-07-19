import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../theme/design_tokens.dart';

class TabItemData {
  final String title;
  final IconData icon;

  const TabItemData({required this.title, required this.icon});
}

class AnimatedTabBar extends StatelessWidget {
  final List<TabItemData> tabs;
  final int activeIndex;
  final ValueChanged<int> onTabChanged;

  const AnimatedTabBar({
    super.key,
    required this.tabs,
    required this.activeIndex,
    required this.onTabChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xxs + 2),
      decoration: BoxDecoration(
        color: AppTheme.backgroundPureDark.withValues(alpha: 0.6),
        border: const Border(
          bottom: BorderSide(color: AppTheme.borderSubtle, width: 1),
        ),
      ),
      child: Row(
        children: List.generate(tabs.length, (index) {
          final tab = tabs[index];
          final isActive = index == activeIndex;

          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: InkWell(
                onTap: () => onTabChanged(index),
                borderRadius: BorderRadius.circular(AppRadius.sm),
                child: AnimatedContainer(
                  duration: AppDuration.fast,
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs + 2),
                  decoration: BoxDecoration(
                    color: isActive
                        ? AppTheme.primaryAccent.withValues(alpha: 0.22)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    border: Border.all(
                      color: isActive
                          ? AppTheme.primaryAccent.withValues(alpha: 0.8)
                          : Colors.transparent,
                      width: 1,
                    ),
                    boxShadow: isActive ? AppShadows.subtle : null,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        tab.icon,
                        size: 13,
                        color: isActive ? AppTheme.primaryAccent : AppTheme.textMuted,
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Text(
                        tab.title,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                          color: isActive ? AppTheme.textPrimary : AppTheme.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}
