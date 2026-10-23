import 'package:flutter/material.dart';

/// Tiny trend line. Null values leave gaps; the last point is dotted.
class Sparkline extends StatelessWidget {
  final List<double?> values;
  final Color color;
  final double width;
  final double height;

  const Sparkline({
    super.key,
    required this.values,
    required this.color,
    this.width = 110,
    this.height = 28,
  });

  @override
  Widget build(BuildContext context) => CustomPaint(
        size: Size(width, height),
        painter: _SparklinePainter(values, color),
      );
}

class _SparklinePainter extends CustomPainter {
  final List<double?> values;
  final Color color;

  _SparklinePainter(this.values, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final present = values.whereType<double>().toList();
    if (present.isEmpty) return;
    var lo = present.reduce((a, b) => a < b ? a : b);
    var hi = present.reduce((a, b) => a > b ? a : b);
    if (hi - lo < 1e-9) {
      lo -= 1;
      hi += 1;
    }
    const pad = 3.0;
    Offset at(int i, double v) {
      final x = values.length == 1 ? size.width / 2 : pad + (size.width - 2 * pad) * i / (values.length - 1);
      final y = size.height - pad - (size.height - 2 * pad) * (v - lo) / (hi - lo);
      return Offset(x, y);
    }

    final line = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round;
    Offset? prev;
    Offset? last;
    for (var i = 0; i < values.length; i++) {
      final v = values[i];
      if (v == null) {
        prev = null;
        continue;
      }
      final p = at(i, v);
      if (prev != null) canvas.drawLine(prev, p, line);
      prev = p;
      last = p;
    }
    if (last != null) canvas.drawCircle(last, 3, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter old) => old.values != values || old.color != color;
}
