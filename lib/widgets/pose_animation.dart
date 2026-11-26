import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

import '../core/motion.dart';
import '../models/exercise.dart';

/// Stick-figure illustrations of each exercise, drawn with the same skeleton
/// style as the live camera overlay. Used for the welcome hero, exercise
/// thumbnails and the exercise detail header.
///
/// Joints: 0 head, 1/2 shoulders, 3/4 elbows, 5/6 wrists, 7/8 hips,
/// 9/10 knees, 11/12 ankles — in a 220×236 design space.
class _Pose {
  const _Pose(this.a, this.b);
  final List<Offset> a; // start pose
  final List<Offset> b; // end pose
}

const _bones = [
  (1, 2), (1, 3), (3, 5), (2, 4), (4, 6), // arms + shoulders
  (1, 7), (2, 8), (7, 8), // torso
  (7, 9), (9, 11), (8, 10), (10, 12), // legs
];

List<Offset> _side(List<double> xy) {
  // side views: left and right joints overlap
  final p = [for (var i = 0; i < xy.length; i += 2) Offset(xy[i], xy[i + 1])];
  // order given: head, shoulder, elbow, wrist, hip, knee, ankle
  return [p[0], p[1], p[1], p[2], p[2], p[3], p[3], p[4], p[4], p[5], p[5], p[6], p[6]];
}

final _poses = <ExerciseKind, _Pose>{
  ExerciseKind.squat: const _Pose(
    [
      Offset(110, 40), Offset(85, 68), Offset(135, 68), Offset(78, 105), Offset(142, 105), Offset(75, 140),
      Offset(145, 140), Offset(93, 130), Offset(127, 130), Offset(91, 172), Offset(129, 172), Offset(90, 210),
      Offset(130, 210),
    ],
    [
      Offset(110, 70), Offset(85, 98), Offset(135, 98), Offset(76, 128), Offset(144, 128), Offset(96, 134),
      Offset(124, 134), Offset(95, 150), Offset(125, 150), Offset(72, 178), Offset(148, 178), Offset(88, 212),
      Offset(132, 212),
    ],
  ),
  ExerciseKind.pushup: _Pose(
    _side([190, 104, 168, 118, 166, 150, 164, 182, 98, 132, 54, 148, 14, 162]),
    _side([194, 144, 172, 154, 146, 166, 164, 182, 98, 160, 54, 168, 14, 172]),
  ),
  ExerciseKind.curl: _Pose(
    _side([110, 40, 108, 72, 110, 118, 112, 162, 106, 132, 108, 182, 106, 226]),
    _side([110, 40, 108, 72, 110, 118, 142, 94, 106, 132, 108, 182, 106, 226]),
  ),
};

class _PosePainter extends CustomPainter {
  _PosePainter(this.kind, this.t, this.color, this.stroke, this.headFill);
  final ExerciseKind kind;
  final double t;
  final Color color;
  final double stroke;
  final Color headFill;

  @override
  void paint(Canvas canvas, Size size) {
    final pose = _poses[kind]!;
    final s = (size.width / 220) < (size.height / 236) ? size.width / 220 : size.height / 236;
    final dx = (size.width - 220 * s) / 2, dy = (size.height - 236 * s) / 2;
    Offset at(int i) {
      final a = pose.a[i], b = pose.b[i];
      return Offset(dx + lerpDouble(a.dx, b.dx, t)! * s, dy + lerpDouble(a.dy, b.dy, t)! * s);
    }

    final line = Paint()
      ..color = color
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    for (final (i, j) in _bones) {
      canvas.drawLine(at(i), at(j), line);
    }
    final head = at(0);
    final r = 12.0 * s;
    canvas.drawCircle(head, r, Paint()..color = headFill);
    canvas.drawCircle(head, r, line);
  }

  @override
  bool shouldRepaint(_PosePainter old) => old.t != t || old.color != color || old.kind != kind;
}

/// Loops between the two poses of an exercise (hold → move → hold → back).
class PoseLoop extends StatefulWidget {
  const PoseLoop({
    super.key,
    required this.kind,
    required this.color,
    this.size = const Size(220, 236),
    this.stroke = 5,
    this.headFill = Colors.white,
    this.period = const Duration(milliseconds: 2400),
  });

  final ExerciseKind kind;
  final Color color;
  final Size size;
  final double stroke;
  final Color headFill;
  final Duration period;

  @override
  State<PoseLoop> createState() => _PoseLoopState();
}

class _PoseLoopState extends State<PoseLoop> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: widget.period);

  static final _seq = TweenSequence<double>([
    TweenSequenceItem(tween: ConstantTween(0.0), weight: 15),
    TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0).chain(CurveTween(curve: Curves.easeInOut)), weight: 30),
    TweenSequenceItem(tween: ConstantTween(1.0), weight: 20),
    TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0).chain(CurveTween(curve: Curves.easeInOut)), weight: 30),
    TweenSequenceItem(tween: ConstantTween(0.0), weight: 5),
  ]);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (Motion.reduced(context)) {
      _c.stop();
    } else if (!_c.isAnimating) {
      _c.repeat();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox.fromSize(
      size: widget.size,
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, __) => CustomPaint(
          painter: _PosePainter(widget.kind, _seq.transform(_c.value), widget.color, widget.stroke, widget.headFill),
        ),
      ),
    );
  }
}

/// Static thumbnail of an exercise (mid-movement pose).
class ExerciseGlyph extends StatelessWidget {
  const ExerciseGlyph({super.key, required this.exercise, this.size = 64});
  final Exercise exercise;
  final double size;

  @override
  Widget build(BuildContext context) {
    final style = exercise.style;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: style.tint, borderRadius: BorderRadius.circular(size * 0.28)),
      padding: EdgeInsets.all(size * 0.14),
      child: CustomPaint(
        painter: _PosePainter(exercise.kind, exercise.kind == ExerciseKind.curl ? 1 : 0.6, style.ink, size * 0.045, style.tint),
      ),
    );
  }
}
