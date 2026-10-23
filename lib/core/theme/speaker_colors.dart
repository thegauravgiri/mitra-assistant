import 'package:flutter/material.dart';

/// Stable per-speaker colours so "Speaker 2" looks the same everywhere.
class SpeakerColors {
  static const List<Color> _palette = [
    Color(0xFF60A5FA), // blue
    Color(0xFFF472B6), // pink
    Color(0xFF34D399), // green
    Color(0xFFFBBF24), // amber
    Color(0xFFA78BFA), // violet
    Color(0xFFF87171), // red
  ];

  static const Color unknown = Color(0xFF94A3B8);

  static Color forIndex(int? speakerIndex) {
    if (speakerIndex == null || speakerIndex < 0) return unknown;
    return _palette[speakerIndex % _palette.length];
  }

  /// Colour for a label like "Speaker 3" (index 2), matching [forIndex].
  static Color forLabel(String label) {
    if (label == 'You') return forIndex(0);
    final m = RegExp(r'^Speaker (\d+)$').firstMatch(label);
    return forIndex(m == null ? null : int.parse(m.group(1)!) - 1);
  }
}
