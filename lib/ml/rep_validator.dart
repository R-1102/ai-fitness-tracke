import 'dart:math' as math;

import 'pose_frame.dart';

/// Outcome of checking one repetition.
enum RepVerdict {
  /// Correct movement, full range.
  valid,

  /// Right exercise but not deep / high enough — counted as a wrong rep.
  shallow,

  /// A different movement (e.g. a burpee while "Squats" is selected) — not counted at all.
  notExercise,

  /// Key joints were not visible — not counted.
  notVisible,
}

class RepCheck {
  const RepCheck(this.verdict, [this.message]);
  const RepCheck.valid() : this(RepVerdict.valid);

  final RepVerdict verdict;
  final String? message;

  /// Whether the rep is counted at all (as correct or wrong).
  bool get counts => verdict == RepVerdict.valid || verdict == RepVerdict.shallow;
  bool get isCorrect => verdict == RepVerdict.valid;
}

/// Guards the up/down model.
///
/// The trained models only know "up" vs "down" for one exercise, so any
/// movement that goes down and up (burpees, sitting, bending over) would be
/// counted. A validator watches every frame of a repetition and checks simple
/// body geometry to confirm it really was the selected exercise.
///
/// The engine calls [reset] when a new repetition starts (stage becomes down)
/// and [validate] when it completes (down -> up). The pipeline calls [observe]
/// for every frame.
abstract class RepValidator {
  void reset();
  void observe(PoseFrame frame);
  RepCheck validate();
}

const _left = (hip: Landmark.leftHip, knee: Landmark.leftKnee, ankle: Landmark.leftAnkle);
const _right = (hip: Landmark.rightHip, knee: Landmark.rightKnee, ankle: Landmark.rightAnkle);

/// Vertical thigh length / vertical shin length. ~1 standing, ~0 at parallel.
/// Uses only vertical distances, so it works from the front and from the side.
double? _thighRatio(PoseFrame f) {
  final side = f.betterSide([_left.hip, _left.knee, _left.ankle], [_right.hip, _right.knee, _right.ankle]);
  if (!f.visible(side)) return null;
  final hip = f[side[0]], knee = f[side[1]], ankle = f[side[2]];
  final shin = ankle.y - knee.y;
  if (shin < 0.02) return null;
  return (knee.y - hip.y) / shin;
}

/// Squats: knees must bend enough, the torso must stay upright and the hands
/// must stay off the floor.
class SquatRepValidator implements RepValidator {
  SquatRepValidator({this.deepRatio = 0.45, this.minRatio = 0.75, this.uprightFraction = 0.55});

  /// Thigh ratio at or below this = full squat.
  final double deepRatio;

  /// Above this the knees barely bent — not a squat.
  final double minRatio;

  /// Torso must keep at least this share of its standing (vertical) length.
  final double uprightFraction;

  double _torsoBaseline = 0; // kept across reps (standing torso length)
  int _frames = 0, _seen = 0;
  double _lowestRatio = double.infinity;
  double _minTorso = double.infinity;
  bool _handsDown = false;

  @override
  void reset() {
    _frames = 0;
    _seen = 0;
    _lowestRatio = double.infinity;
    _minTorso = double.infinity;
    _handsDown = false;
  }

  @override
  void observe(PoseFrame f) {
    _frames++;
    final ratio = _thighRatio(f);
    if (ratio == null) return;
    _seen++;
    _lowestRatio = math.min(_lowestRatio, ratio);

    final torso = f.midHip.y - f.midShoulder.y;
    _torsoBaseline = math.max(_torsoBaseline, torso);
    _minTorso = math.min(_minTorso, torso);

    // Hands lower than mid-shin => on the floor (burpee / bear crawl).
    for (final (w, k, a) in const [
      (Landmark.leftWrist, Landmark.leftKnee, Landmark.leftAnkle),
      (Landmark.rightWrist, Landmark.rightKnee, Landmark.rightAnkle),
    ]) {
      if (f.visible([w, k, a]) && f[w].y > (f[k].y + f[a].y) / 2) _handsDown = true;
    }
  }

  @override
  RepCheck validate() {
    if (_seen == 0 || _seen < _frames / 2) {
      return const RepCheck(RepVerdict.notVisible, 'Step back so your legs and feet are visible');
    }
    final upright = _torsoBaseline <= 0 || _minTorso >= _torsoBaseline * uprightFraction;
    if (_handsDown || !upright) return const RepCheck(RepVerdict.notExercise, 'That doesn\'t look like a squat');
    if (_lowestRatio > minRatio) return const RepCheck(RepVerdict.notExercise, 'Bend your knees to squat');
    if (_lowestRatio > deepRatio) return const RepCheck(RepVerdict.shallow, 'Go lower — aim for thighs parallel');
    return const RepCheck.valid();
  }
}

/// Push-ups: body must stay roughly horizontal and elbows must bend.
class PushupRepValidator implements RepValidator {
  PushupRepValidator({this.minTilt = 50, this.deepElbow = 105, this.minElbowBend = 140});

  final double minTilt;
  final double deepElbow;
  final double minElbowBend;

  int _frames = 0, _seen = 0;
  double _lowestTilt = double.infinity;
  double _smallestElbow = double.infinity;

  @override
  void reset() {
    _frames = 0;
    _seen = 0;
    _lowestTilt = double.infinity;
    _smallestElbow = double.infinity;
  }

  @override
  void observe(PoseFrame f) {
    _frames++;
    final arm = f.betterSide(
      [Landmark.leftShoulder, Landmark.leftElbow, Landmark.leftWrist, Landmark.leftHip],
      [Landmark.rightShoulder, Landmark.rightElbow, Landmark.rightWrist, Landmark.rightHip],
    );
    if (!f.visible(arm)) return;
    _seen++;
    _lowestTilt = math.min(_lowestTilt, f.torsoTilt);
    _smallestElbow = math.min(_smallestElbow, f.jointAngle(arm[0], arm[1], arm[2]));
  }

  @override
  RepCheck validate() {
    if (_seen == 0 || _seen < _frames / 2) {
      return const RepCheck(RepVerdict.notVisible, 'Make sure your whole body is in view');
    }
    if (_lowestTilt < minTilt) return const RepCheck(RepVerdict.notExercise, 'Get into a plank — that doesn\'t look like a push-up');
    if (_smallestElbow > minElbowBend) return const RepCheck(RepVerdict.notExercise, 'Bend your elbows to lower down');
    if (_smallestElbow > deepElbow) return const RepCheck(RepVerdict.shallow, 'Go lower — chest closer to the floor');
    return const RepCheck.valid();
  }
}

/// Bicep curls: stand upright, keep the legs still, curl through full range.
class CurlRepValidator implements RepValidator {
  CurlRepValidator({this.maxTilt = 35, this.fullCurl = 70, this.minCurl = 115, this.bentLegsRatio = 0.6});

  final double maxTilt;
  final double fullCurl;
  final double minCurl;
  final double bentLegsRatio;

  int _frames = 0, _seen = 0;
  double _highestTilt = 0;
  double _smallestElbow = double.infinity;
  double _lowestThigh = double.infinity;

  @override
  void reset() {
    _frames = 0;
    _seen = 0;
    _highestTilt = 0;
    _smallestElbow = double.infinity;
    _lowestThigh = double.infinity;
  }

  @override
  void observe(PoseFrame f) {
    _frames++;
    final arm = f.betterSide(
      [Landmark.leftShoulder, Landmark.leftElbow, Landmark.leftWrist],
      [Landmark.rightShoulder, Landmark.rightElbow, Landmark.rightWrist],
    );
    if (!f.visible(arm)) return;
    _seen++;
    _smallestElbow = math.min(_smallestElbow, f.jointAngle(arm[0], arm[1], arm[2]));
    if (f.visible([Landmark.leftHip, Landmark.rightHip])) _highestTilt = math.max(_highestTilt, f.torsoTilt);
    final thigh = _thighRatio(f); // legs are optional for curls (upper-body framing)
    if (thigh != null) _lowestThigh = math.min(_lowestThigh, thigh);
  }

  @override
  RepCheck validate() {
    if (_seen == 0 || _seen < _frames / 2) {
      return const RepCheck(RepVerdict.notVisible, 'Make sure your arm is in view');
    }
    if (_highestTilt > maxTilt) return const RepCheck(RepVerdict.notExercise, 'Stand upright while curling');
    if (_lowestThigh < bentLegsRatio) return const RepCheck(RepVerdict.notExercise, 'Keep your legs still — that doesn\'t look like a curl');
    if (_smallestElbow > minCurl) return const RepCheck(RepVerdict.notExercise, 'Curl the weight all the way up');
    if (_smallestElbow > fullCurl) return const RepCheck(RepVerdict.shallow, 'Curl higher — squeeze at the top');
    return const RepCheck.valid();
  }
}