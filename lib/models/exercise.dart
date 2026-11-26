import 'dart:ui' show Color;

import '../ml/form_analyzers.dart';

enum BodyPart { upper, lower }

/// Which illustration to draw for an exercise.
enum ExerciseKind { squat, pushup, curl }

enum Level {
  beginner('Beginner', 8),
  intermediate('Intermediate', 12),
  advanced('Advanced', 15);

  const Level(this.label, this.repsPerSet);

  final String label;
  final int repsPerSet;
  static const setsPerWorkout = 3;

  static Level fromName(String? name) =>
      Level.values.firstWhere((l) => l.name == name, orElse: () => Level.beginner);
}

enum FormCheck { bicepAngle, squatKnees, pushupModel }

/// Tint colours for thumbnails/headers.
class ExerciseStyle {
  const ExerciseStyle(this.tint, this.ink, this.halo);
  final Color tint;
  final Color ink;
  final Color halo;

  static const blue = ExerciseStyle(Color(0xFFE8EEFF), Color(0xFF2F6BFF), Color(0xFFD6E1FF));
  static const orange = ExerciseStyle(Color(0xFFFFF0E6), Color(0xFFD9480F), Color(0xFFFFE2CF));
  static const neutral = ExerciseStyle(Color(0xFFEEF1F6), Color(0xFF0E1B2C), Color(0xFFDDE2EA));
}

class Exercise {
  const Exercise({
    required this.id,
    required this.name,
    required this.description,
    required this.muscles,
    required this.minutes,
    required this.bodyParts,
    required this.kind,
    required this.style,
    required this.upDownModelAsset,
    required this.formCheck,
    required this.checkLabel,
    required this.aiSteps,
    required this.fixTip,
    required this.met,
    required this.cameraTip,
    this.formModelAsset,
    this.initialStage = MoveStage.down,
  });

  final String id;
  final String name;
  final String description;
  final String muscles;
  final int minutes;
  final Set<BodyPart> bodyParts;
  final ExerciseKind kind;
  final ExerciseStyle style;
  final String upDownModelAsset;
  final String? formModelAsset;
  final FormCheck formCheck;
  final MoveStage initialStage;

  /// Short name of what the AI checks ("Knee alignment").
  final String checkLabel;

  /// "How the AI checks you" — (title, detail) pairs.
  final List<(String, String)> aiSteps;

  /// Coaching tip used in insights when reps were flagged.
  final String fixTip;

  /// Metabolic equivalent used for the calorie estimate (Compendium of
  /// Physical Activities). Replaces the hard-coded `cal_per_min` values that
  /// lived in the old shared database.
  final double met;

  /// How to place the phone so the model sees the right angle.
  final String cameraTip;

  /// kcal = MET × 3.5 × weight(kg) / 200 × minutes
  double caloriesFor(Duration duration, double weightKg) =>
      met * 3.5 * weightKg / 200 * (duration.inSeconds / 60);

  static Exercise byId(String id) => all.firstWhere((e) => e.id == id, orElse: () => all.first);

  static List<Exercise> forBodyPart(BodyPart part) =>
      all.where((e) => e.bodyParts.contains(part)).toList();

  static const _tracks = ('Tracks 33 body points', 'on your phone — video never leaves the device.');

  static const all = <Exercise>[
    Exercise(
      id: 'squat',
      name: 'Squats',
      description:
          'Squats strengthen the lower body. Bend your knees and lower your hips, then '
          'return to standing. Builds functional strength, balance and mobility.',
      muscles: 'Legs · Glutes',
      minutes: 8,
      bodyParts: {BodyPart.lower},
      kind: ExerciseKind.squat,
      style: ExerciseStyle.orange,
      upDownModelAsset: 'assets/models/squat_updown.json',
      formCheck: FormCheck.squatKnees,
      checkLabel: 'Knee alignment',
      aiSteps: [
        _tracks,
        ('Counts each rep', 'when you go down and come back up.'),
        ('Checks your knees', 'stay in line with your feet. If they cave in, the rep is flagged.'),
      ],
      fixTip: 'Your knees moved inward on {n} squats. Try a slightly wider stance and push your knees out.',
      initialStage: MoveStage.up,
      met: 5.0,
      cameraTip: 'Prop your phone 2–3 m away, facing you, so knees and feet are in frame.',
    ),
    Exercise(
      id: 'pushup',
      name: 'Push-ups',
      description:
          'Push-ups strengthen the chest, shoulders and triceps. Start in a plank with '
          'hands shoulder-width apart, lower until your chest nearly touches the ground, '
          'then push back up.',
      muscles: 'Chest · Triceps',
      minutes: 6,
      bodyParts: {BodyPart.upper, BodyPart.lower},
      kind: ExerciseKind.pushup,
      style: ExerciseStyle.blue,
      upDownModelAsset: 'assets/models/pushup_updown.json',
      formModelAsset: 'assets/models/pushup_form.json',
      formCheck: FormCheck.pushupModel,
      checkLabel: 'Body line model',
      aiSteps: [
        _tracks,
        ('Counts each rep', 'when your chest goes down and you push back up.'),
        ('Checks your body line', 'with a trained model. Sagging or piking hips flag the rep.'),
      ],
      fixTip: 'Your body line broke on {n} push-ups. Squeeze your core and glutes to stay straight.',
      met: 8.0,
      cameraTip: 'Place the phone on the floor to your side so your whole body is visible.',
    ),
    Exercise(
      id: 'hammer_curl',
      name: 'Hammer curls',
      description:
          'Targets the biceps and forearms. Hold the dumbbells with palms facing each '
          'other and curl them up while keeping your elbows fixed.',
      muscles: 'Biceps · Forearms',
      minutes: 7,
      bodyParts: {BodyPart.upper},
      kind: ExerciseKind.curl,
      style: ExerciseStyle.blue,
      upDownModelAsset: 'assets/models/hammer_curl_updown.json',
      formCheck: FormCheck.bicepAngle,
      checkLabel: 'Elbow angle',
      aiSteps: [
        _tracks,
        ('Counts each rep', 'from arm straight to fully curled.'),
        ('Checks your elbow', 'stays by your side. If it drifts forward, the rep is flagged.'),
      ],
      fixTip: 'Your elbow drifted forward on {n} curls. Pin it to your side and lift slower.',
      met: 3.5,
      cameraTip: 'Stand sideways to the camera, 2–3 m away, with your upper body in frame.',
    ),
    Exercise(
      id: 'barbell_curl',
      name: 'Barbell curls',
      description:
          'A classic strength exercise for the biceps. Hold a barbell with an underhand '
          'grip and curl it up while keeping your elbows steady.',
      muscles: 'Biceps',
      minutes: 7,
      bodyParts: {BodyPart.upper},
      kind: ExerciseKind.curl,
      style: ExerciseStyle.neutral,
      upDownModelAsset: 'assets/models/barbell_curl_updown.json',
      formCheck: FormCheck.bicepAngle,
      checkLabel: 'Elbow angle',
      aiSteps: [
        _tracks,
        ('Counts each rep', 'from arms straight to fully curled.'),
        ('Checks your elbows', 'stay by your sides. If they drift forward, the rep is flagged.'),
      ],
      fixTip: 'Your elbows drifted forward on {n} curls. Keep them tucked and avoid swinging.',
      met: 3.5,
      cameraTip: 'Stand sideways to the camera, 2–3 m away, with your upper body in frame.',
    ),
  ];
}
