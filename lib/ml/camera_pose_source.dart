import 'dart:io';
import 'dart:ui' show Size;

import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

import 'pose_frame.dart';

/// Converts camera frames to ML Kit input and ML Kit poses to [PoseFrame]s
/// normalised to [0, 1] — the same coordinate system MediaPipe used in the
/// original Python app, so the trained models see the same kind of input.
class CameraPoseSource {
  CameraPoseSource()
      : _detector = PoseDetector(
          options: PoseDetectorOptions(mode: PoseDetectionMode.stream, model: PoseDetectionModel.base),
        );

  final PoseDetector _detector;

  static const _orientations = {
    DeviceOrientation.portraitUp: 0,
    DeviceOrientation.landscapeLeft: 90,
    DeviceOrientation.portraitDown: 180,
    DeviceOrientation.landscapeRight: 270,
  };

  static ImageFormatGroup get imageFormatGroup =>
      Platform.isAndroid ? ImageFormatGroup.nv21 : ImageFormatGroup.bgra8888;

  /// Returns the first detected pose, or null if nobody is in frame.
  Future<PoseFrame?> detect(CameraImage image, CameraController controller) async {
    final input = _toInputImage(image, controller);
    if (input == null) return null;

    final poses = await _detector.processImage(input);
    if (poses.isEmpty) return null;

    final metadata = input.metadata!;
    final rotated = metadata.rotation == InputImageRotation.rotation90deg ||
        metadata.rotation == InputImageRotation.rotation270deg;
    // Same convention as ML Kit's official example (coordinates_translator.dart).
    final swap = rotated && Platform.isAndroid;
    final w = swap ? metadata.size.height : metadata.size.width;
    final h = swap ? metadata.size.width : metadata.size.height;

    final landmarks = poses.first.landmarks;
    final points = <PosePoint>[
      for (final type in PoseLandmarkType.values)
        if (landmarks[type] case final lm?)
          PosePoint(lm.x / w, lm.y / h, lm.likelihood)
        else
          const PosePoint(0, 0, 0),
    ];
    return PoseFrame(points, aspect: w / h);
  }

  InputImage? _toInputImage(CameraImage image, CameraController controller) {
    final camera = controller.description;
    final sensorOrientation = camera.sensorOrientation;

    InputImageRotation? rotation;
    if (Platform.isIOS) {
      rotation = InputImageRotationValue.fromRawValue(sensorOrientation);
    } else if (Platform.isAndroid) {
      var compensation = _orientations[controller.value.deviceOrientation];
      if (compensation == null) return null;
      compensation = camera.lensDirection == CameraLensDirection.front
          ? (sensorOrientation + compensation) % 360
          : (sensorOrientation - compensation + 360) % 360;
      rotation = InputImageRotationValue.fromRawValue(compensation);
    }
    if (rotation == null) return null;

    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    if (format == null ||
        (Platform.isAndroid && format != InputImageFormat.nv21) ||
        (Platform.isIOS && format != InputImageFormat.bgra8888)) {
      return null;
    }
    if (image.planes.length != 1) return null;
    final plane = image.planes.first;

    return InputImage.fromBytes(
      bytes: plane.bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: plane.bytesPerRow,
      ),
    );
  }

  Future<void> close() => _detector.close();
}
