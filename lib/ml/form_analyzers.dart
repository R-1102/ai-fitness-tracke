import 'pose_classifier.dart';
import 'pose_frame.dart';

/// Which half of the movement the user is in, as predicted by the up/down model.
enum MoveStage { up, down }

class FormResult {
  const FormResult.correct([this.detail])
      : isCorrect = true,
        feedback = null;
  const FormResult.wrong(this.feedback, [this.detail]) : isCorrect = false;

  final bool isCorrect;

  /// Short coaching cue shown to the user when the form is wrong.
  final String? feedback;

  /// Optional debug value (angle, ratio, probability...).
  final double? detail;
}

/// Checks whether a repetition is performed correctly.
abstract interface class FormAnalyzer {
  FormResult analyze(PoseFrame frame, MoveStage stage, List<double> features);
}

/// Bicep curls (hammer + barbell).
///
/// Port of `BicepPoseAnalysis`: measures the angle between the upper arm and
/// the vertical line through the shoulder. If the elbow drifts away from the
/// body the rep is counted as wrong.
///
/// Change vs. the original: the original looped over both arms but only kept
/// the right one (the loop overwrote the result). Here we analyse the arm that
/// is more visible to the camera.
class BicepCurlFormAnalyzer implements FormAnalyzer {
  const BicepCurlFormAnalyzer({this.elbowDriftThreshold = 12});

  /// Degrees. Original code: `ground_upper_arm_angle >= 12` => wrong.
  final double elbowDriftThreshold;

  @override
  FormResult analyze(PoseFrame frame, MoveStage stage, List<double> features) {
    final left = _armVisibility(frame, Landmark.leftShoulder, Landmark.leftElbow);
    final right = _armVisibility(frame, Landmark.rightShoulder, Landmark.rightElbow);
    final useLeft = left > right;

    final shoulder = frame[useLeft ? Landmark.leftShoulder : Landmark.rightShoulder];
    final elbow = frame[useLeft ? Landmark.leftElbow : Landmark.rightElbow];
    final projection = PosePoint(shoulder.x, 1);
    final angle = angleBetween(elbow, shoulder, projection);

    return angle >= elbowDriftThreshold
        ? FormResult.wrong('Keep your elbow close to your body', angle)
        : FormResult.correct(angle);
  }

  double _armVisibility(PoseFrame f, int shoulder, int elbow) =>
      f[shoulder].likelihood + f[elbow].likelihood;
}

/// Squats. Port of `analyze_foot_knee_placement`: compares the distance
/// between the knees with the distance between the feet.
class SquatFormAnalyzer implements FormAnalyzer {
  const SquatFormAnalyzer({
    this.upRange = (min: 0.56, max: 1.0),
    this.downRange = (min: 0.7, max: 1.1),
  });

  final ({double min, double max}) upRange;
  final ({double min, double max}) downRange;

  @override
  FormResult analyze(PoseFrame frame, MoveStage stage, List<double> features) {
    final footWidth = frame[Landmark.leftFootIndex].distanceTo(frame[Landmark.rightFootIndex]);
    if (footWidth < 1e-6) return const FormResult.correct();

    final kneeWidth = frame[Landmark.leftKnee].distanceTo(frame[Landmark.rightKnee]);
    final ratio = (kneeWidth / footWidth * 10).roundToDouble() / 10;
    final range = stage == MoveStage.up ? upRange : downRange;

    return ratio < range.min
        ? FormResult.wrong('Knees caving in — push them out', ratio)
        : FormResult.correct(ratio);
  }
}

/// Push-ups: a second trained model classifies the pose as right/wrong.
class ModelFormAnalyzer implements FormAnalyzer {
  const ModelFormAnalyzer(this.model, {this.threshold = 0.65, required this.feedback});

  final PoseClassifier model;
  final double threshold;
  final String feedback;

  @override
  FormResult analyze(PoseFrame frame, MoveStage stage, List<double> features) {
    // Original: `pRW[0][1] > 0.65` => "Right"
    final pRight = model.predict(features)[1];
    return pRight > threshold ? FormResult.correct(pRight) : FormResult.wrong(feedback, pRight);
  }
}
