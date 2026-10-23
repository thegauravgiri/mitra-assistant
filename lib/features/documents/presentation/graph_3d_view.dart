import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../core/theme/graph_palette.dart';
import '../data/graph_camera.dart';
import '../data/graph_layout_3d.dart';
import '../data/label_placer.dart';
import '../domain/models/doc_graph.dart';

/// Draws one node glyph. Shape (not just colour) carries the node type, so the
/// graph stays readable for colour-blind users.
void paintNodeShape(Canvas canvas, NodeShape shape, Offset c, double r, Paint fill, {Paint? outline}) {
  Path path;
  switch (shape) {
    case NodeShape.circle:
      canvas.drawCircle(c, r, fill);
      if (outline != null) canvas.drawCircle(c, r, outline);
      return;
    case NodeShape.square:
      final rr = RRect.fromRectAndRadius(Rect.fromCenter(center: c, width: r * 1.75, height: r * 1.75), Radius.circular(r * 0.3));
      canvas.drawRRect(rr, fill);
      if (outline != null) canvas.drawRRect(rr, outline);
      return;
    case NodeShape.diamond:
      final d = r * 1.3;
      path = Path()
        ..moveTo(c.dx, c.dy - d)
        ..lineTo(c.dx + d, c.dy)
        ..lineTo(c.dx, c.dy + d)
        ..lineTo(c.dx - d, c.dy)
        ..close();
    case NodeShape.triangle:
      path = Path()
        ..moveTo(c.dx, c.dy - r * 1.3)
        ..lineTo(c.dx + r * 1.15, c.dy + r * 0.9)
        ..lineTo(c.dx - r * 1.15, c.dy + r * 0.9)
        ..close();
    case NodeShape.pentagon:
      path = Path();
      for (var i = 0; i < 5; i++) {
        final a = -math.pi / 2 + 2 * math.pi / 5 * i;
        final p = Offset(c.dx + math.cos(a) * r * 1.25, c.dy + math.sin(a) * r * 1.25);
        i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
      }
      path.close();
    case NodeShape.hexagon:
      path = Path();
      for (var i = 0; i < 6; i++) {
        final a = math.pi / 3 * i + math.pi / 6;
        final p = Offset(c.dx + math.cos(a) * r * 1.2, c.dy + math.sin(a) * r * 1.2);
        i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
      }
      path.close();
  }
  canvas.drawPath(path, fill);
  if (outline != null) canvas.drawPath(path, outline);
}

/// Small legend / chip glyph for a node type.
class ShapeGlyph extends StatelessWidget {
  final String type;
  final double size;

  const ShapeGlyph(this.type, {super.key, this.size = 14});

  @override
  Widget build(BuildContext context) {
    final style = NodeStyles.of(type);
    return CustomPaint(size: Size.square(size), painter: _GlyphPainter(style));
  }
}

class _GlyphPainter extends CustomPainter {
  final NodeStyle style;

  _GlyphPainter(this.style);

  @override
  void paint(Canvas canvas, Size size) =>
      paintNodeShape(canvas, style.shape, size.center(Offset.zero), size.width * 0.34, Paint()..color = style.color);

  @override
  bool shouldRepaint(covariant _GlyphPainter old) => old.style.shape != style.shape || old.style.color != style.color;
}

class _Hit {
  final Offset pos;
  final double radius;
  final double depth;
  const _Hit(this.pos, this.radius, this.depth);
}

/// Everything the painter reads. Notifying repaints without rebuilding widgets.
class _Scene extends ChangeNotifier {
  GraphCamera camera = const GraphCamera();
  String? selected;
  String? hover;
  final Map<String, _Hit> hits = {};

  void changed() => notifyListeners();
}

/// Interactive 3D node-link view: drag to orbit, scroll or pinch to zoom,
/// click a node to focus it and read its links. Pure Flutter drawing.
class Graph3DCanvas extends StatefulWidget {
  final DocGraph graph;
  final Widget Function(String nodeId, VoidCallback onClose) detailsBuilder;

  /// Screenshot harness only: preselects a node id when the canvas opens.
  static String? debugInitialSelection;

  const Graph3DCanvas({super.key, required this.graph, required this.detailsBuilder});

  @override
  State<Graph3DCanvas> createState() => _Graph3DCanvasState();
}

class _Graph3DCanvasState extends State<Graph3DCanvas> with SingleTickerProviderStateMixin {
  final _Scene _scene = _Scene();
  late final Future<GraphPositions3D> _layout;
  late final Ticker _ticker;
  Duration _last = Duration.zero;
  bool _autoRotate = true;
  bool _dragging = false;
  double _baseZoom = 1;

  @override
  void initState() {
    super.initState();
    _layout = GraphLayout3D.runAsync(widget.graph);
    _scene.selected = Graph3DCanvas.debugInitialSelection;
    if (_scene.selected != null) _autoRotate = false;
    _ticker = createTicker(_onTick)..start();
  }

  void _onTick(Duration elapsed) {
    final dt = (elapsed - _last).inMicroseconds / 1e6;
    _last = elapsed;
    if (_autoRotate && !_dragging && _scene.selected == null && _scene.hover == null) {
      _scene.camera = _scene.camera.copyWith(yaw: _scene.camera.yaw + dt * 0.14);
      _scene.changed();
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    _scene.dispose();
    super.dispose();
  }

  void _zoomBy(double factor) {
    _scene.camera = _scene.camera.copyWith(zoom: _scene.camera.zoom * factor);
    _scene.changed();
  }

  void _select(String? id) {
    setState(() => _scene.selected = id);
    _scene.changed();
  }

  String? _hitTest(Offset p) {
    String? best;
    var bestDepth = -2.0;
    _scene.hits.forEach((id, h) {
      if ((h.pos - p).distance <= h.radius + 6 && h.depth > bestDepth) {
        best = id;
        bestDepth = h.depth;
      }
    });
    return best;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<GraphPositions3D>(
      future: _layout,
      builder: (context, snap) {
        if (!snap.hasData) return const Center(child: CircularProgressIndicator(strokeWidth: 2));
        final pos = snap.data!;
        final types = {for (final n in widget.graph.nodes) n.type}.toList();

        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: ClipRect(
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: Listener(
                        onPointerSignal: (e) {
                          if (e is PointerScrollEvent) _zoomBy(math.exp(-e.scrollDelta.dy / 500));
                        },
                        child: MouseRegion(
                          onHover: (e) {
                            final h = _hitTest(e.localPosition);
                            if (h != _scene.hover) {
                              _scene.hover = h;
                              _scene.changed();
                            }
                          },
                          onExit: (_) {
                            _scene.hover = null;
                            _scene.changed();
                          },
                          cursor: SystemMouseCursors.grab,
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTapUp: (d) => _select(_hitTest(d.localPosition)),
                            onDoubleTap: () {
                              _scene.camera = const GraphCamera();
                              _scene.changed();
                            },
                            onScaleStart: (_) {
                              _dragging = true;
                              _baseZoom = _scene.camera.zoom;
                            },
                            onScaleUpdate: (d) {
                              _scene.camera = _scene.camera.copyWith(
                                yaw: _scene.camera.yaw + d.focalPointDelta.dx * 0.009,
                                pitch: _scene.camera.pitch + d.focalPointDelta.dy * 0.009,
                                zoom: d.scale == 1 ? null : _baseZoom * d.scale,
                              );
                              _scene.changed();
                            },
                            onScaleEnd: (_) => _dragging = false,
                            child: CustomPaint(
                              painter: _ScenePainter(widget.graph, pos, _scene),
                              size: Size.infinite,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: AppSpacing.md,
                      right: AppSpacing.md,
                      child: _Controls(
                        autoRotate: _autoRotate,
                        onToggleRotate: () => setState(() => _autoRotate = !_autoRotate),
                        onZoomIn: () => _zoomBy(1.25),
                        onZoomOut: () => _zoomBy(0.8),
                        onReset: () {
                          _scene.camera = const GraphCamera();
                          _scene.changed();
                        },
                      ),
                    ),
                    Positioned(left: AppSpacing.md, bottom: AppSpacing.md, child: _Legend(types: types)),
                    const Positioned(
                      left: AppSpacing.md,
                      top: AppSpacing.md,
                      child: Text(
                        'Drag to rotate · scroll to zoom · click a node',
                        style: TextStyle(fontSize: 10.5, color: AppTheme.textMuted),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (_scene.selected != null)
              widget.detailsBuilder(_scene.selected!, () => _select(null)),
          ],
        );
      },
    );
  }
}

class _Controls extends StatelessWidget {
  final bool autoRotate;
  final VoidCallback onToggleRotate;
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;
  final VoidCallback onReset;

  const _Controls({
    required this.autoRotate,
    required this.onToggleRotate,
    required this.onZoomIn,
    required this.onZoomOut,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    Widget btn(IconData icon, String tip, VoidCallback onTap, {bool active = false}) => Tooltip(
          message: tip,
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: onTap,
            child: Container(
              width: 32,
              height: 32,
              alignment: Alignment.center,
              child: Icon(icon, size: 17, color: active ? AppTheme.primaryAccent : AppTheme.textSecondary),
            ),
          ),
        );

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.backgroundPureDark.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.borderSubtle),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          btn(Icons.add_rounded, 'Zoom in', onZoomIn),
          btn(Icons.remove_rounded, 'Zoom out', onZoomOut),
          btn(Icons.threed_rotation_rounded, autoRotate ? 'Stop auto-rotate' : 'Auto-rotate', onToggleRotate, active: autoRotate),
          btn(Icons.center_focus_strong_rounded, 'Reset view', onReset),
        ],
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  final List<String> types;

  const _Legend({required this.types});

  @override
  Widget build(BuildContext context) {
    final seen = <String>{};
    final entries = [
      for (final t in types)
        if (seen.add('${NodeStyles.of(t).shape}/${NodeStyles.of(t).color}')) t,
    ];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppTheme.backgroundPureDark.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.borderSubtle),
      ),
      child: Wrap(
        spacing: AppSpacing.md,
        runSpacing: 4,
        children: [
          for (final t in entries)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ShapeGlyph(t),
                const SizedBox(width: 5),
                Text(NodeStyles.of(t).label, style: const TextStyle(fontSize: 10.5, color: AppTheme.textSecondary)),
              ],
            ),
        ],
      ),
    );
  }
}

class _ScenePainter extends CustomPainter {
  final DocGraph graph;
  final GraphPositions3D pos;
  final _Scene scene;

  final Map<String, int> _degree = {};
  final Map<String, TextPainter> _text = {};

  static const _structural = {'attended', 'from', 'decided in', 'unanswered in', 'mentions'};
  static const _bridge = 'same as'; // links a document entity to a meeting topic/person
  static const _strong = {'owns', 'asked', 'raised'};

  _ScenePainter(this.graph, this.pos, this.scene) : super(repaint: scene) {
    for (final e in graph.edges) {
      _degree[e.from] = (_degree[e.from] ?? 0) + 1;
      _degree[e.to] = (_degree[e.to] ?? 0) + 1;
    }
  }

  TextPainter _label(String text, double size, Color color, {FontWeight w = FontWeight.w500}) {
    final key = '$text|$size|${color.toARGB32()}|${w.value}';
    return _text.putIfAbsent(
      key,
      () => TextPainter(
        text: TextSpan(text: text, style: TextStyle(fontSize: size, color: color, fontWeight: w)),
        textDirection: ui.TextDirection.ltr,
        maxLines: 1,
        ellipsis: '…',
      )..layout(maxWidth: 170),
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = ui.Gradient.radial(
          size.center(Offset.zero),
          size.shortestSide * 0.75,
          [const Color(0xFF16203A), GraphPalette.surface],
        ),
    );

    final cam = scene.camera;
    final centre = size.center(Offset.zero);
    final radiusPx = size.shortestSide * 0.46;

    final proj = <String, Projected>{
      for (final n in graph.nodes)
        if (pos[n.id] != null) n.id: cam.project(pos[n.id]!, radiusPx),
    };

    final small = graph.nodes.length <= 25; // label everything when there is room
    final focus = scene.selected ?? scene.hover;
    final related = <String>{};
    if (focus != null) {
      related
        ..add(focus)
        ..addAll(graph.neighboursOf(focus));
    }
    double depthAlpha(double d) => 0.4 + 0.6 * (d + 1) / 2;

    final labelCandidates = <LabelCandidate>[];
    final edgeLabels = <String, (TextPainter, Rect)>{};

    // ---- edges
    for (final e in graph.edges) {
      final a = proj[e.from], b = proj[e.to];
      if (a == null || b == null) continue;
      final pa = centre + Offset(a.x, a.y);
      final pb = centre + Offset(b.x, b.y);
      final depth = (a.depth + b.depth) / 2;
      final active = focus != null && (e.from == focus || e.to == focus);

      final isBridge = e.relation == _bridge;
      final tierAlpha = _structural.contains(e.relation) ? 0.5 : (_strong.contains(e.relation) ? 0.9 : 0.7);
      final tierWidth = _structural.contains(e.relation) ? 1.2 : (_strong.contains(e.relation) ? 2.0 : 1.5);

      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;
      if (active) {
        final ca = NodeStyles.of(graph.node(e.from)!.type).color;
        final cb = NodeStyles.of(graph.node(e.to)!.type).color;
        paint
          ..strokeWidth = 2.0
          ..shader = ui.Gradient.linear(pa, pb, [ca.withValues(alpha: 0.95), cb.withValues(alpha: 0.95)]);
        canvas.drawLine(pa, pb, paint);
        _arrow(canvas, pa, pb, cb, a.scale);
        final tp = _label(e.relation, 10, AppTheme.textSecondary);
        // Try the middle first, then nearer each end, so a label that collides
        // at one spot can still appear at another.
        final key = 'e:${e.from}|${e.relation}|${e.to}';
        var rank = 0;
        for (final t in const [0.5, 0.33, 0.67]) {
          final at = Offset.lerp(pa, pb, t)!;
          final r = Rect.fromCenter(center: at, width: tp.width + 8, height: tp.height + 4);
          edgeLabels['$key#$rank'] = (tp, r);
          labelCandidates.add(LabelCandidate('$key#$rank', 60.0 - rank * 5 + depth * 5, r));
          rank++;
        }
      } else {
        final dim = focus != null ? 0.18 : 1.0;
        paint
          ..strokeWidth = (isBridge ? 2.2 : tierWidth) * (0.8 + 0.4 * (depth + 1) / 2)
          ..color = (isBridge ? Colors.white : GraphPalette.edge)
              .withValues(alpha: (isBridge ? 0.85 : tierAlpha) * (0.6 + 0.4 * (depth + 1) / 2) * dim);
        if (isBridge) {
          _dashed(canvas, pa, pb, paint); // dashed + bright: "this document names the same thing"
        } else {
          canvas.drawLine(pa, pb, paint);
        }
      }
    }

    // ---- nodes, back to front
    scene.hits.clear();
    final order = proj.entries.toList()..sort((a, b) => a.value.depth.compareTo(b.value.depth));
    final surfaceRing = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..color = GraphPalette.surface;
    final labelText = <String, (TextPainter, Offset)>{};

    for (final entry in order) {
      final node = graph.node(entry.key)!;
      final p = entry.value;
      final c = centre + Offset(p.x, p.y);
      final style = NodeStyles.of(node.type);
      final weight = math.max(node.chunkIndexes.length, node.sourceIds.length);
      final isMeeting = node.type == 'meeting';
      final base = (isMeeting ? 8.5 : 5.5) + 1.8 * math.min(weight, 4) + 0.6 * math.min(_degree[node.id] ?? 0, 6);
      final r = base * p.scale * math.pow(cam.zoom, 0.35).toDouble();
      final dimmed = focus != null && !related.contains(node.id);
      final alpha = (dimmed ? 0.22 : 1.0) * depthAlpha(p.depth);

      paintNodeShape(canvas, style.shape, c, r, Paint()..color = style.color.withValues(alpha: alpha), outline: surfaceRing);
      if (node.id == scene.selected) {
        canvas.drawCircle(
          c,
          r + 5,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..color = Colors.white.withValues(alpha: 0.9),
        );
      }
      scene.hits[node.id] = _Hit(c, r, p.depth);

      // label candidate
      final front = p.depth > -0.3;
      final isFocus = node.id == scene.selected || node.id == scene.hover;
      final inFocus = related.contains(node.id);
      final important = isMeeting || node.type == 'topic' || node.type == 'person' || (_degree[node.id] ?? 0) >= 4;
      final show = isFocus ||
          (focus != null
              ? inFocus
              : ((front && important) || (small && p.depth > -0.5) || (cam.zoom > 1.8 && p.depth > -0.2)));
      if (!show) continue;
      final tp = _label(
        node.name,
        isFocus ? 12.5 : 11,
        isFocus ? Colors.white : AppTheme.textPrimary.withValues(alpha: math.max(0.55, depthAlpha(p.depth))),
        w: isFocus ? FontWeight.w700 : FontWeight.w500,
      );
      final topLeft = Offset(c.dx - tp.width / 2, c.dy + r + 4);
      labelText[node.id] = (tp, topLeft);
      labelCandidates.add(LabelCandidate(
        node.id,
        isFocus
            ? 1000.0
            : (inFocus ? 500.0 + (_degree[node.id] ?? 0) : (isMeeting ? 100.0 : 0.0) + (_degree[node.id] ?? 0) + p.depth * 5),
        topLeft & tp.size,
      ));
    }

    final placed = LabelPlacer.place(labelCandidates, bounds: rect.deflate(4), max: focus != null ? 60 : (small ? 30 : 16));
    final drawnEdges = <String>{};
    for (final id in placed) {
      final edge = edgeLabels[id];
      if (edge != null) {
        if (!drawnEdges.add(id.substring(0, id.lastIndexOf('#')))) continue;
        final (tp, r) = edge;
        canvas.drawRRect(
          RRect.fromRectAndRadius(r, const Radius.circular(4)),
          Paint()..color = GraphPalette.surface.withValues(alpha: 0.88),
        );
        tp.paint(canvas, r.topLeft + const Offset(4, 2));
        continue;
      }
      final (tp, topLeft) = labelText[id]!;
      canvas.drawRRect(
        RRect.fromRectAndRadius((topLeft & tp.size).inflate(2.5), const Radius.circular(4)),
        Paint()..color = GraphPalette.surface.withValues(alpha: 0.72),
      );
      tp.paint(canvas, topLeft);
    }
  }

  void _dashed(Canvas canvas, Offset a, Offset b, Paint paint) {
    final v = b - a;
    final len = v.distance;
    if (len < 1) return;
    final dir = v / len;
    for (var d = 0.0; d < len; d += 10) {
      canvas.drawLine(a + dir * d, a + dir * math.min(d + 6, len), paint);
    }
  }

  void _arrow(Canvas canvas, Offset from, Offset to, Color color, double scale) {
    final v = to - from;
    final len = v.distance;
    if (len < 24) return;
    final dir = v / len;
    final tip = to - dir * 12 * scale; // stop short of the node
    final size = 7.0 * scale;
    final normal = Offset(-dir.dy, dir.dx);
    final path = Path()
      ..moveTo(tip.dx, tip.dy)
      ..lineTo(tip.dx - dir.dx * size + normal.dx * size * 0.55, tip.dy - dir.dy * size + normal.dy * size * 0.55)
      ..lineTo(tip.dx - dir.dx * size - normal.dx * size * 0.55, tip.dy - dir.dy * size - normal.dy * size * 0.55)
      ..close();
    canvas.drawPath(path, Paint()..color = color.withValues(alpha: 0.95));
  }

  @override
  bool shouldRepaint(covariant _ScenePainter old) => old.graph != graph || old.pos != pos;
}
