import 'package:cloud_firestore/cloud_firestore.dart';

import '../ml/workout_engine.dart' show SetResult;
import 'exercise.dart';

/// One completed (or stopped) workout. Stored per user in
/// `users/{uid}/sessions/{sessionId}` — the old app wrote calories to a single
/// shared node, so every user overwrote everyone else's report.
class WorkoutSession {
  const WorkoutSession({
    this.id,
    required this.exerciseId,
    required this.level,
    required this.correctReps,
    required this.wrongReps,
    required this.completedSets,
    required this.duration,
    required this.calories,
    required this.createdAt,
    this.sets = const [],
  });

  final String? id;
  final String exerciseId;
  final Level level;
  final int correctReps;
  final int wrongReps;
  final int completedSets;
  final Duration duration;
  final double calories;
  final DateTime createdAt;

  /// Per-set breakdown (empty for sessions saved by older versions).
  final List<SetResult> sets;

  Exercise get exercise => Exercise.byId(exerciseId);

  int get totalReps => correctReps + wrongReps;

  /// Share of reps performed with correct form (0..1).
  double get accuracy => totalReps == 0 ? 0 : correctReps / totalReps;

  factory WorkoutSession.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final m = doc.data() ?? const {};
    return WorkoutSession(
      id: doc.id,
      exerciseId: m['exerciseId'] as String? ?? 'pushup',
      level: Level.fromName(m['level'] as String?),
      correctReps: (m['correctReps'] as num?)?.toInt() ?? 0,
      wrongReps: (m['wrongReps'] as num?)?.toInt() ?? 0,
      completedSets: (m['completedSets'] as num?)?.toInt() ?? 0,
      duration: Duration(seconds: (m['durationSec'] as num?)?.toInt() ?? 0),
      calories: (m['calories'] as num?)?.toDouble() ?? 0,
      createdAt: (m['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      sets: [
        for (final raw in (m['sets'] as List? ?? const []))
          if (raw is Map)
            SetResult((raw['correct'] as num?)?.toInt() ?? 0, (raw['wrong'] as num?)?.toInt() ?? 0),
      ],
    );
  }

  Map<String, dynamic> toMap() => {
        'exerciseId': exerciseId,
        'level': level.name,
        'correctReps': correctReps,
        'wrongReps': wrongReps,
        'completedSets': completedSets,
        'durationSec': duration.inSeconds,
        'calories': double.parse(calories.toStringAsFixed(1)),
        'createdAt': Timestamp.fromDate(createdAt),
        'sets': [
          for (final set in sets) {'correct': set.correct, 'wrong': set.wrong},
        ],
      };
}
