import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:mitra_assistant/features/documents/data/graph_camera.dart';
import 'package:mitra_assistant/features/documents/data/graph_layout_3d.dart';
import 'package:mitra_assistant/features/documents/data/label_placer.dart';
import 'package:mitra_assistant/features/documents/domain/models/doc_graph.dart';

void main() {
  GraphNode n(String id) => GraphNode(id: id, name: id);
  GraphEdge e(String a, String b) => GraphEdge(from: a, to: b, relation: 'r', chunkIndex: 0);
  double dist(Vec3 a, Vec3 b) =>
      math.sqrt(math.pow(a.x - b.x, 2) + math.pow(a.y - b.y, 2) + math.pow(a.z - b.z, 2));

  group('GraphLayout3D', () {
    test('empty and single-node graphs', () {
      expect(GraphLayout3D.run(DocGraph.empty()), isEmpty);
      expect(GraphLayout3D.run(DocGraph(nodes: [n('a')], edges: const [])).values.single, (x: 0.0, y: 0.0, z: 0.0));
    });

    test('stays inside the unit sphere, nodes are distinct, and it is deterministic', () {
      final g = DocGraph(
        nodes: [for (var i = 0; i < 40; i++) n('n$i')],
        edges: [for (var i = 1; i < 40; i++) e('n${i ~/ 2}', 'n$i')],
      );
      final a = GraphLayout3D.run(g);
      expect(a, GraphLayout3D.run(g));
      expect(a.length, 40);
      for (final p in a.values) {
        expect(math.sqrt(p.x * p.x + p.y * p.y + p.z * p.z), lessThanOrEqualTo(1.0001));
      }
      expect(a.values.toSet().length, 40);
      // really three-dimensional: depth is used, not a flat sheet
      final zs = a.values.map((p) => p.z);
      expect(zs.reduce(math.max) - zs.reduce(math.min), greaterThan(0.5));
    });

    test('connected nodes end up closer than the average pair', () {
      final g = DocGraph(nodes: [for (var i = 0; i < 14; i++) n('n$i')], edges: [e('n0', 'n1')]);
      final p = GraphLayout3D.run(g);
      var total = 0.0;
      for (var i = 2; i < 14; i++) {
        total += dist(p['n0']!, p['n$i']!);
      }
      expect(dist(p['n0']!, p['n1']!), lessThan(total / 12));
    });
  });

  group('GraphCamera', () {
    test('origin projects to the centre; nearer points are larger', () {
      const cam = GraphCamera(yaw: 0, pitch: 0);
      final c = cam.project((x: 0, y: 0, z: 0), 200);
      expect(c.x, 0);
      expect(c.y, 0);
      final near = cam.project((x: 0.5, y: 0, z: 1), 200);
      final far = cam.project((x: 0.5, y: 0, z: -1), 200);
      expect(near.x, greaterThan(far.x)); // same x, bigger when nearer
      expect(near.depth, 1);
      expect(far.depth, -1);
      expect(near.scale, greaterThan(far.scale));
    });

    test('yaw of 90 degrees brings the +x axis to the front', () {
      final cam = const GraphCamera(yaw: math.pi / 2, pitch: 0);
      final p = cam.project((x: 1, y: 0, z: 0), 200);
      expect(p.x.abs(), lessThan(1e-6));
      expect(p.depth, closeTo(-1, 1e-6)); // rotated away from the camera
    });

    test('zoom and pitch are clamped', () {
      const cam = GraphCamera();
      expect(cam.copyWith(zoom: 99).zoom, GraphCamera.maxZoom);
      expect(cam.copyWith(zoom: 0).zoom, GraphCamera.minZoom);
      expect(cam.copyWith(pitch: 9).pitch, GraphCamera.maxPitch);
    });
  });

  group('LabelPlacer', () {
    const bounds = Rect.fromLTWH(0, 0, 400, 300);
    test('places by priority and skips overlaps', () {
      final ids = LabelPlacer.place([
        const LabelCandidate('low', 1, Rect.fromLTWH(100, 100, 80, 14)),
        const LabelCandidate('high', 9, Rect.fromLTWH(110, 104, 80, 14)), // overlaps "low"
        const LabelCandidate('other', 5, Rect.fromLTWH(10, 10, 60, 14)),
      ], bounds: bounds);
      expect(ids, ['high', 'other']);
    });

    test('skips labels that leave the view and respects the max', () {
      final ids = LabelPlacer.place([
        const LabelCandidate('out', 9, Rect.fromLTWH(380, 10, 60, 14)),
        for (var i = 0; i < 10; i++) LabelCandidate('l$i', 1, Rect.fromLTWH(10, 20.0 * i + 5, 50, 12)),
      ], bounds: bounds, max: 3);
      expect(ids.contains('out'), isFalse);
      expect(ids.length, 3);
    });
  });
}
