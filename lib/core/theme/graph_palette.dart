import 'package:flutter/material.dart';

/// Node and status colours for the graph and the coaching report.
///
/// Node colours use the first three slots of the validated categorical palette
/// (blue, orange, aqua), the most that pass the all-pairs colour-blind and
/// normal-vision checks on a dark surface. Everything beyond three groups is
/// told apart by SHAPE and label, never by colour alone.
class GraphPalette {
  static const Color surface = Color(0xFF0B1020);

  static const Color blue = Color(0xFF3987E5); // topics, orgs
  static const Color orange = Color(0xFFD95926); // people
  static const Color aqua = Color(0xFF199E70); // outcomes (decisions, actions, questions), products
  static const Color neutral = Color(0xFFCBD5E1); // meetings (the hubs)
  static const Color muted = Color(0xFF94A3B8); // everything else

  static const Color edge = Color(0xFFB4C2DC);
}

enum NodeShape { circle, diamond, square, triangle, hexagon, pentagon }

class NodeStyle {
  final Color color;
  final NodeShape shape;
  final String label;
  const NodeStyle(this.color, this.shape, this.label);
}

/// One place that decides how every node type looks.
class NodeStyles {
  static NodeStyle of(String type) {
    switch (type) {
      case 'meeting':
        return const NodeStyle(GraphPalette.neutral, NodeShape.hexagon, 'Meeting');
      case 'document':
        return const NodeStyle(GraphPalette.muted, NodeShape.pentagon, 'Document');
      case 'topic':
        return const NodeStyle(GraphPalette.blue, NodeShape.circle, 'Topic');
      case 'person':
        return const NodeStyle(GraphPalette.orange, NodeShape.circle, 'Person');
      case 'decision':
        return const NodeStyle(GraphPalette.aqua, NodeShape.diamond, 'Decision');
      case 'action':
        return const NodeStyle(GraphPalette.aqua, NodeShape.square, 'Action');
      case 'question':
        return const NodeStyle(GraphPalette.aqua, NodeShape.triangle, 'Open question');
      // document graph entity types
      case 'org':
        return const NodeStyle(GraphPalette.blue, NodeShape.square, 'Organisation');
      case 'product':
        return const NodeStyle(GraphPalette.aqua, NodeShape.circle, 'Product');
      case 'metric':
        return const NodeStyle(GraphPalette.aqua, NodeShape.diamond, 'Metric');
      case 'date':
        return const NodeStyle(GraphPalette.muted, NodeShape.triangle, 'Date');
      case 'place':
        return const NodeStyle(GraphPalette.muted, NodeShape.hexagon, 'Place');
      default:
        return const NodeStyle(GraphPalette.muted, NodeShape.circle, 'Concept');
    }
  }
}

/// Fixed status palette (good / warning / serious), always paired with an icon
/// and a word, never colour alone.
class StatusStyle {
  final Color color;
  final IconData icon;
  final String word;
  const StatusStyle(this.color, this.icon, this.word);

  static const good = StatusStyle(Color(0xFF0CA30C), Icons.check_circle_rounded, 'On track');
  static const ok = StatusStyle(Color(0xFFFAB219), Icons.info_rounded, 'Fine');
  static const watch = StatusStyle(Color(0xFFEC835A), Icons.error_rounded, 'Worth a look');
  static const unknown = StatusStyle(Color(0xFF94A3B8), Icons.remove_circle_outline_rounded, 'Not measurable');
}
