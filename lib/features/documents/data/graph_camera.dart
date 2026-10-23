import 'dart:math' as math;
import 'graph_layout_3d.dart';

class Projected {
  final double x; // screen x, relative to the view centre
  final double y;
  final double depth; // -1 (far) .. +1 (near)
  final double scale; // perspective scale, 1.0 at the centre plane

  const Projected(this.x, this.y, this.depth, this.scale);
}

/// Orbit camera around the origin: yaw/pitch rotate the scene, zoom scales it,
/// perspective makes nearer nodes larger.
class GraphCamera {
  final double yaw;
  final double pitch;
  final double zoom;

  const GraphCamera({this.yaw = 0.6, this.pitch = -0.35, this.zoom = 1});

  static const double distance = 3.2; // camera distance in scene units
  static const double minZoom = 0.45;
  static const double maxZoom = 4.5;
  static const double maxPitch = 1.45;

  GraphCamera copyWith({double? yaw, double? pitch, double? zoom}) => GraphCamera(
        yaw: yaw ?? this.yaw,
        pitch: (pitch ?? this.pitch).clamp(-maxPitch, maxPitch),
        zoom: (zoom ?? this.zoom).clamp(minZoom, maxZoom),
      );

  /// [radiusPx] is the on-screen size of the unit sphere at zoom 1.
  Projected project(Vec3 p, double radiusPx) {
    // rotate around Y (yaw), then X (pitch)
    final cy = math.cos(yaw), sy = math.sin(yaw);
    final x1 = p.x * cy + p.z * sy;
    final z1 = -p.x * sy + p.z * cy;
    final cp = math.cos(pitch), sp = math.sin(pitch);
    final y2 = p.y * cp - z1 * sp;
    final z2 = p.y * sp + z1 * cp;

    final scale = distance / (distance - z2); // z2 > 0 is towards the camera
    final k = radiusPx * zoom * scale;
    return Projected(x1 * k, y2 * k, z2.clamp(-1.0, 1.0), scale);
  }
}
