import 'dart:math' as math;

/// A single body landmark with coordinates normalised to [0, 1] relative to
/// the upright image (same convention as MediaPipe's `pose_landmarks`).
class PosePoint {
  const PosePoint(this.x, this.y, [this.likelihood = 1.0]);

  final double x;
  final double y;
  final double likelihood;

  double distanceTo(PosePoint other) =>
      math.sqrt(math.pow(other.x - x, 2) + math.pow(other.y - y, 2));
}

/// The 33 BlazePose landmarks of one frame, in MediaPipe order.
///
/// Google ML Kit's `PoseLandmarkType.values` uses exactly the same order, so
/// the models trained with MediaPipe in the original project work unchanged.
class PoseFrame {
  PoseFrame(this.points, {this.aspect = 1.0})
      : assert(points.length == landmarkCount,
  'Expected $landmarkCount landmarks, got ${points.length}');

  static const int landmarkCount = 33;

  final List<PosePoint> points;

  /// Image width / height. x and y are normalised separately, so angles are
  /// computed after scaling x by this to get square (undistorted) units.
  final double aspect;

  PosePoint operator [](int index) => points[index];

  bool visible(Iterable<int> indices, [double minLikelihood = 0.5]) =>
      indices.every((i) => points[i].likelihood >= minLikelihood);

  double _visibility(Iterable<int> indices) => indices.fold(0.0, (s, i) => s + points[i].likelihood);

  /// Returns [left] or [right], whichever set of joints is more visible.
  List<int> betterSide(List<int> left, List<int> right) =>
      _visibility(left) >= _visibility(right) ? left : right;

  /// Angle at joint [b] (degrees, 0..180) in undistorted image space.
  double jointAngle(int a, int b, int c) {
    PosePoint iso(int i) => PosePoint(points[i].x * aspect, points[i].y);
    return angleBetween(iso(a), iso(b), iso(c));
  }

  PosePoint _mid(int a, int b) =>
      PosePoint((points[a].x + points[b].x) / 2, (points[a].y + points[b].y) / 2);

  PosePoint get midShoulder => _mid(Landmark.leftShoulder, Landmark.rightShoulder);
  PosePoint get midHip => _mid(Landmark.leftHip, Landmark.rightHip);

  /// Torso angle from vertical in degrees: 0 = upright, 90 = horizontal.
  double get torsoTilt {
    final s = midShoulder, h = midHip;
    final dx = ((s.x - h.x) * aspect).abs();
    final dy = h.y - s.y; // positive when shoulders are above hips
    return math.atan2(dx, dy) * 180 / math.pi;
  }
}

/// MediaPipe / ML Kit landmark indices used by the form analysers.
abstract final class Landmark {
  static const nose = 0;
  static const leftShoulder = 11;
  static const rightShoulder = 12;
  static const leftElbow = 13;
  static const rightElbow = 14;
  static const leftWrist = 15;
  static const rightWrist = 16;
  static const leftHip = 23;
  static const rightHip = 24;
  static const leftKnee = 25;
  static const rightKnee = 26;
  static const leftAnkle = 27;
  static const rightAnkle = 28;
  static const leftFootIndex = 31;
  static const rightFootIndex = 32;
}

/// Angle in degrees at [vertex] formed by [a] and [c] (0..180).
/// Port of `calculate_angle()` from the original Python code.
double angleBetween(PosePoint a, PosePoint vertex, PosePoint c) {
  final radians = math.atan2(c.y - vertex.y, c.x - vertex.x) -
      math.atan2(a.y - vertex.y, a.x - vertex.x);
  var degrees = (radians * 180.0 / math.pi).abs();
  if (degrees > 180) degrees = 360 - degrees;
  return degrees;
}
