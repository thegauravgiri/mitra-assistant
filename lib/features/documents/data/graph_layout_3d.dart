import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import '../domain/models/doc_graph.dart';

typedef Vec3 = ({double x, double y, double z});

/// Node id -> position inside the unit sphere (centred on the origin).
typedef GraphPositions3D = Map<String, Vec3>;

class _Input {
  final List<String> ids;
  final List<(int, int)> edges;
  final int iterations;
  const _Input(this.ids, this.edges, this.iterations);
}

/// 3D force-directed layout (Fruchterman-Reingold). Deterministic: starts from
/// a Fibonacci sphere in node order, no randomness, so the same graph always
/// looks the same.
class GraphLayout3D {
  static GraphPositions3D run(DocGraph graph, {int iterations = 220}) =>
      _layout(_input(graph, iterations));

  /// Same result, computed off the UI isolate.
  static Future<GraphPositions3D> runAsync(DocGraph graph, {int iterations = 220}) =>
      compute(_layout, _input(graph, iterations));

  static _Input _input(DocGraph g, int iterations) {
    final ids = [for (final n in g.nodes) n.id];
    final index = {for (var i = 0; i < ids.length; i++) ids[i]: i};
    return _Input(
      ids,
      [
        for (final e in g.edges)
          if (index.containsKey(e.from) && index.containsKey(e.to) && e.from != e.to)
            (index[e.from]!, index[e.to]!),
      ],
      iterations,
    );
  }

  static GraphPositions3D _layout(_Input input) {
    final n = input.ids.length;
    if (n == 0) return {};
    if (n == 1) return {input.ids.first: (x: 0, y: 0, z: 0)};

    final x = List<double>.filled(n, 0);
    final y = List<double>.filled(n, 0);
    final z = List<double>.filled(n, 0);
    const golden = 2.399963229728653; // golden angle
    for (var i = 0; i < n; i++) {
      final yy = 1 - 2 * (i + 0.5) / n;
      final r = math.sqrt(math.max(0, 1 - yy * yy));
      x[i] = math.cos(golden * i) * r;
      y[i] = yy;
      z[i] = math.sin(golden * i) * r;
    }

    // ideal distance for n nodes filling the unit-ish ball
    final k = math.pow(8.0 / n, 1 / 3) * 0.9;
    var temp = 0.35;
    final cooling = temp / (input.iterations + 1);

    for (var it = 0; it < input.iterations; it++) {
      final dx = List<double>.filled(n, 0);
      final dy = List<double>.filled(n, 0);
      final dz = List<double>.filled(n, 0);

      for (var i = 0; i < n; i++) {
        for (var j = i + 1; j < n; j++) {
          var vx = x[i] - x[j];
          var vy = y[i] - y[j];
          var vz = z[i] - z[j];
          var d = math.sqrt(vx * vx + vy * vy + vz * vz);
          if (d < 1e-4) {
            vx = 1e-3 * (i + 1);
            vy = 1e-3 * (j + 1);
            vz = 1e-3;
            d = math.sqrt(vx * vx + vy * vy + vz * vz);
          }
          final f = k * k / d;
          dx[i] += vx / d * f;
          dy[i] += vy / d * f;
          dz[i] += vz / d * f;
          dx[j] -= vx / d * f;
          dy[j] -= vy / d * f;
          dz[j] -= vz / d * f;
        }
      }

      for (final (a, b) in input.edges) {
        final vx = x[a] - x[b];
        final vy = y[a] - y[b];
        final vz = z[a] - z[b];
        final d = math.max(math.sqrt(vx * vx + vy * vy + vz * vz), 1e-4);
        final f = d * d / k;
        dx[a] -= vx / d * f;
        dy[a] -= vy / d * f;
        dz[a] -= vz / d * f;
        dx[b] += vx / d * f;
        dy[b] += vy / d * f;
        dz[b] += vz / d * f;
      }

      for (var i = 0; i < n; i++) {
        // gravity keeps disconnected components in view
        dx[i] -= x[i] * 0.05;
        dy[i] -= y[i] * 0.05;
        dz[i] -= z[i] * 0.05;
        final d = math.max(math.sqrt(dx[i] * dx[i] + dy[i] * dy[i] + dz[i] * dz[i]), 1e-6);
        final step = math.min(d, temp);
        x[i] += dx[i] / d * step;
        y[i] += dy[i] / d * step;
        z[i] += dz[i] / d * step;
      }
      temp -= cooling;
    }

    // centre and scale into the unit sphere
    var cx = 0.0, cy = 0.0, cz = 0.0;
    for (var i = 0; i < n; i++) {
      cx += x[i];
      cy += y[i];
      cz += z[i];
    }
    cx /= n;
    cy /= n;
    cz /= n;
    var maxR = 1e-6;
    for (var i = 0; i < n; i++) {
      x[i] -= cx;
      y[i] -= cy;
      z[i] -= cz;
      maxR = math.max(maxR, math.sqrt(x[i] * x[i] + y[i] * y[i] + z[i] * z[i]));
    }
    return {for (var i = 0; i < n; i++) input.ids[i]: (x: x[i] / maxR, y: y[i] / maxR, z: z[i] / maxR)};
  }
}
