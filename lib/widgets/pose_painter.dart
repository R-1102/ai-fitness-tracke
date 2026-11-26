import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../ml/pose_frame.dart';

/// Draws the detected skeleton over the camera preview.
/// Green = good form, red = wrong form (same idea as the original OpenCV UI).
class PosePainter extends CustomPainter {
  PosePainter({required this.frame, required this.formOk, required this.mirror});

  final PoseFrame? frame;
  final bool formOk;
  final bool mirror;

  static const _connections = [
    (11, 12), (11, 13), (13, 15), (12, 14), (14, 16), // arms
    (11, 23), (12, 24), (23, 24), // torso
    (23, 25), (25, 27), (27, 31), (24, 26), (26, 28), (28, 32), // legs
    (27, 29), (29, 31), (28, 30), (30, 32), // feet
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final f = frame;
    if (f == null) return;

    Offset toCanvas(PosePoint p) => Offset((mirror ? 1 - p.x : p.x) * size.width, p.y * size.height);

    final color = formOk ? AppColors.accent : AppColors.warn;
    final line = Paint()
      ..color = color
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    final dot = Paint()..color = Colors.white;

    for (final (a, b) in _connections) {
      if (f[a].likelihood < 0.5 || f[b].likelihood < 0.5) continue;
      canvas.drawLine(toCanvas(f[a]), toCanvas(f[b]), line);
    }
    for (var i = 11; i < PoseFrame.landmarkCount; i++) {
      if (f[i].likelihood < 0.5) continue;
      canvas.drawCircle(toCanvas(f[i]), 4, dot);
    }
  }

  @override
  bool shouldRepaint(PosePainter old) => old.frame != frame || old.formOk != formOk || old.mirror != mirror;
}
