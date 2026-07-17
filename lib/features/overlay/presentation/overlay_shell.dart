import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import 'compact_mode.dart';
import 'expanded_mode.dart';

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
          duration: const Duration(milliseconds: 200),
          child: _isCompact
              ? CompactModeView(onExpand: _toggleCompactMode)
              : ExpandedModeView(onCollapse: _toggleCompactMode),
        ),
      ),
    );
  }
}
