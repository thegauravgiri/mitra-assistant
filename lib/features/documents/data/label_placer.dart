import 'dart:ui';

class LabelCandidate {
  final String id;
  final double priority; // higher is placed first
  final Rect rect;

  const LabelCandidate(this.id, this.priority, this.rect);
}

/// Greedy label placement: highest priority first, a label is skipped if it
/// would overlap one already placed or leave the view. Keeps the graph
/// readable instead of drawing every name on top of the others.
class LabelPlacer {
  static List<String> place(
    List<LabelCandidate> candidates, {
    required Rect bounds,
    int max = 40,
    double padding = 2,
  }) {
    final sorted = [...candidates]..sort((a, b) => b.priority.compareTo(a.priority));
    final placed = <Rect>[];
    final ids = <String>[];
    for (final c in sorted) {
      if (ids.length >= max) break;
      final r = c.rect.inflate(padding);
      if (r.left < bounds.left || r.right > bounds.right || r.top < bounds.top || r.bottom > bounds.bottom) continue;
      if (placed.any((p) => p.overlaps(r))) continue;
      placed.add(r);
      ids.add(c.id);
    }
    return ids;
  }
}
