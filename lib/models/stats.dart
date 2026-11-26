import 'exercise.dart';
import 'workout_session.dart';

/// Aggregates over a list of sessions (Home, Progress, Summary).
class WorkoutStats {
  WorkoutStats(this.sessions);

  final List<WorkoutSession> sessions;

  /// Correct reps per day shown as the Home ring goal.
  static const dailyRepGoal = 100;

  int get workouts => sessions.length;
  int get correctReps => sessions.fold(0, (s, e) => s + e.correctReps);
  int get wrongReps => sessions.fold(0, (s, e) => s + e.wrongReps);
  double get calories => sessions.fold(0.0, (s, e) => s + e.calories);
  Duration get duration => sessions.fold(Duration.zero, (s, e) => s + e.duration);

  double get accuracy {
    final total = correctReps + wrongReps;
    return total == 0 ? 0 : correctReps / total;
  }

  WorkoutStats where(bool Function(WorkoutSession s) test) => WorkoutStats(sessions.where(test).toList());

  WorkoutStats between(DateTime from, DateTime to) =>
      where((s) => !s.createdAt.isBefore(from) && s.createdAt.isBefore(to));

  WorkoutStats forExercise(String id) => where((s) => s.exerciseId == id);

  WorkoutStats get today {
    final d = _day(DateTime.now());
    return between(d, d.add(const Duration(days: 1)));
  }

  WorkoutStats month(DateTime anyDayInMonth) {
    final start = DateTime(anyDayInMonth.year, anyDayInMonth.month);
    return between(start, DateTime(start.year, start.month + 1));
  }

  /// Days (midnight) that have at least one workout.
  Set<DateTime> get activeDays => sessions.map((s) => _day(s.createdAt)).toSet();

  /// Correct reps per calendar day in the given month (day -> reps).
  Map<int, int> repsByDay(DateTime anyDayInMonth) {
    final out = <int, int>{};
    for (final s in month(anyDayInMonth).sessions) {
      out.update(s.createdAt.day, (v) => v + s.correctReps, ifAbsent: () => s.correctReps);
    }
    return out;
  }

  /// Consecutive days (ending today or yesterday) with at least one workout.
  int get streak {
    final days = activeDays;
    var day = _day(DateTime.now());
    if (!days.contains(day)) day = DateTime(day.year, day.month, day.day - 1);
    var count = 0;
    while (days.contains(day)) {
      count++;
      day = DateTime(day.year, day.month, day.day - 1);
    }
    return count;
  }

  /// Best form accuracy ever reached on an exercise (0 if never done).
  double bestAccuracy(String exerciseId) => forExercise(exerciseId)
      .sessions
      .where((s) => s.totalReps > 0)
      .fold(0.0, (best, s) => s.accuracy > best ? s.accuracy : best);

  static DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);
}

/// Turns workout history into short coaching messages (the "AI insight" card).
abstract final class Insights {
  /// Exercise that needs the most attention in the last 14 days, if any.
  static Exercise? focusExercise(List<WorkoutSession> history) {
    final since = DateTime.now().subtract(const Duration(days: 14));
    final recent = history.where((s) => s.createdAt.isAfter(since) && s.wrongReps > 0);
    if (recent.isEmpty) return null;
    final wrongBy = <String, int>{};
    for (final s in recent) {
      wrongBy.update(s.exerciseId, (v) => v + s.wrongReps, ifAbsent: () => s.wrongReps);
    }
    final worst = wrongBy.entries.reduce((a, b) => a.value >= b.value ? a : b);
    return Exercise.byId(worst.key);
  }

  static String home(List<WorkoutSession> history) {
    if (history.isEmpty) {
      return 'Finish your first workout and I\'ll start spotting patterns in your form.';
    }
    final focus = focusExercise(history);
    if (focus == null) {
      return 'No form issues in the last two weeks — great job. Ready to try a higher level?';
    }
    final since = DateTime.now().subtract(const Duration(days: 14));
    final n = history
        .where((s) => s.exerciseId == focus.id && s.createdAt.isAfter(since))
        .fold(0, (sum, s) => sum + s.wrongReps);
    return focus.fixTip.replaceAll('{n}', '$n');
  }

  static String session(WorkoutSession s) {
    if (s.totalReps == 0) return 'No reps were detected. Check the camera tip and make sure your whole body is in frame.';
    if (s.wrongReps == 0) {
      return s.level == Level.advanced
          ? 'Every rep was clean. Outstanding control!'
          : 'Every rep was clean — you could move up to the next level.';
    }
    final lateSets = s.sets.isNotEmpty && s.sets.last.wrong >= s.sets.first.wrong && s.sets.length > 1;
    final tip = s.exercise.fixTip.replaceAll('{n}', '${s.wrongReps}');
    return lateSets ? '$tip Most issues came later in the workout — slow down when you get tired.' : tip;
  }
}
