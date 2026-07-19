import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import 'compact_mode.dart';
import 'expanded_mode.dart';
import '../../../core/theme/design_tokens.dart';

class OverlayShell extends StatefulWidget {
  const OverlayShell({super.key});

  @override
  State<OverlayShell> createState() => _OverlayShellState();
}

class _OverlayShellState extends State<OverlayShell> {
  bool _isCompact = false;

  void _toggleCompactMode() async {
    setState(() {
      _isCompact = !_isCompact;
    });

    if (_isCompact) {
      await windowManager.setSize(const Size(380, 56));
    } else {
      await windowManager.setSize(const Size(420, 680));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: AnimatedSwitcher(
          duration: AppDuration.normal,
          switchInCurve: Curves.easeInOut,
          switchOutCurve: Curves.easeInOut,
          transitionBuilder: (child, animation) {
            return FadeTransition(
              opacity: animation,
              child: ScaleTransition(
                scale: Tween<double>(begin: 0.96, end: 1.0).animate(animation),
                child: child,
              ),
            );
          },
          child: _isCompact
              ? CompactModeView(
                  key: const ValueKey('compact_view'),
                  onExpand: _toggleCompactMode,
                )
              : ExpandedModeView(
                  key: const ValueKey('expanded_view'),
                  onCollapse: _toggleCompactMode,
                ),
        ),
      ),
    );
  }
}
