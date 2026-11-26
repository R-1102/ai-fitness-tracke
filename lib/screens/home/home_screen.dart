import 'package:flutter/material.dart';

import '../../core/motion.dart';
import '../../core/theme.dart';
import '../../models/exercise.dart';
import '../../models/stats.dart';
import '../../services/services.dart';
import '../../widgets/ui.dart';
import '../workout/exercise_detail_screen.dart';
import '../workout/workouts_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.onOpenWorkouts});

  final VoidCallback onOpenWorkouts;

  static String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 18) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    final profile = ProfileScope.of(context);
    final history = SessionsScope.of(context);
    final stats = WorkoutStats(history);
    final todayReps = stats.today.correctReps;
    final focus = Insights.focusExercise(history) ?? Exercise.all.first;
    Widget stagger(int i, Widget child) => Entrance(delay: Motion.stagger(i, stepMs: 70), child: child);

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        children: [
          stagger(0, Row(
            children: [
              InitialAvatar(name: profile.name),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(_greeting(), style: const TextStyle(fontSize: 13, color: AppColors.muted)),
                  Text(profile.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800), overflow: TextOverflow.ellipsis),
                ]),
              ),
            ],
          )),
          const SizedBox(height: 18),
          _WeekStrip(activeDays: stats.activeDays),
          const SizedBox(height: 18),
          stagger(1, _GoalCard(
            reps: todayReps,
            focus: focus,
            onContinue: () => Navigator.of(context).push(scopedRoute(context, ExerciseDetailScreen(exercise: focus))),
          )),
          const SizedBox(height: 18),
          stagger(2, SectionHeader('Workouts', action: 'See all', onAction: onOpenWorkouts)),
          const SizedBox(height: 4),
          stagger(2, Row(
            children: [
              Expanded(child: _CategoryTile(part: BodyPart.upper)),
              const SizedBox(width: 10),
              Expanded(child: _CategoryTile(part: BodyPart.lower)),
            ],
          )),
          const SizedBox(height: 18),
          stagger(3, InsightCard(title: 'AI insight', text: Insights.home(history))),
        ],
      ),
    );
  }
}

/// Sun–Sat of the current week; dots mark workout days, today is navy.
class _WeekStrip extends StatelessWidget {
  const _WeekStrip({required this.activeDays});
  final Set<DateTime> activeDays;

  static const _letters = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final sunday = DateTime(today.year, today.month, today.day - today.weekday % 7);
    DateTime dayAt(int i) => DateTime(sunday.year, sunday.month, sunday.day + i); // DST-safe
    return Row(
      children: [
        for (var i = 0; i < 7; i++) ...[
          if (i > 0) const SizedBox(width: 6),
          Expanded(
            child: Entrance(
              delay: Duration(milliseconds: 50 + i * 40),
              offset: 8,
              child: _Day(
                letter: _letters[i],
                date: dayAt(i),
                isToday: dayAt(i) == today,
                done: activeDays.contains(dayAt(i)),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _Day extends StatelessWidget {
  const _Day({required this.letter, required this.date, required this.isToday, required this.done});
  final String letter;
  final DateTime date;
  final bool isToday;
  final bool done;

  @override
  Widget build(BuildContext context) {
    final fg = isToday ? Colors.white : AppColors.ink;
    return Container(
      height: 64,
      decoration: BoxDecoration(
        color: isToday ? AppColors.ink : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isToday ? AppColors.ink : AppColors.border),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(letter, style: TextStyle(fontSize: 11, color: fg.withValues(alpha: 0.8))),
          Text('${date.day}', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: fg)),
          const SizedBox(height: 2),
          Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: done ? (isToday ? Colors.white : AppColors.accent) : Colors.transparent,
            ),
          ),
        ],
      ),
    );
  }
}

class _GoalCard extends StatelessWidget {
  const _GoalCard({required this.reps, required this.focus, required this.onContinue});
  final int reps;
  final Exercise focus;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    const goal = WorkoutStats.dailyRepGoal;
    final left = (goal - reps).clamp(0, goal);
    final headline = reps == 0
        ? 'Let\'s get moving today'
        : left == 0
            ? 'Daily goal reached!'
            : '$left reps to go${left <= goal ~/ 2 ? ' — you\'re close' : ''}';
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: AppColors.ink, borderRadius: BorderRadius.circular(AppRadius.xl)),
      child: Row(
        children: [
          AnimatedRing(
            value: reps / goal,
            size: 104,
            stroke: 10,
            color: AppColors.accent,
            trackColor: AppColors.navyTrack,
            delay: const Duration(milliseconds: 350),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              CountUp(
                value: reps,
                delay: const Duration(milliseconds: 350),
                style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: Colors.white),
              ),
              const Text('/ $goal reps', style: TextStyle(fontSize: 11, color: AppColors.onNavyMuted)),
            ]),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Daily goal', style: TextStyle(fontSize: 12, color: AppColors.onNavyMuted)),
                Text(headline, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, height: 1.25, color: Colors.white)),
                const SizedBox(height: 10),
                Pressable(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(44),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      textStyle: const TextStyle(fontFamily: kFont, fontSize: 14, fontWeight: FontWeight.w700),
                    ),
                    onPressed: onContinue,
                    icon: const Icon(Icons.play_arrow_rounded, size: 18),
                    label: Text('Start: ${focus.name}', overflow: TextOverflow.ellipsis),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({required this.part});
  final BodyPart part;

  @override
  Widget build(BuildContext context) {
    final upper = part == BodyPart.upper;
    final list = Exercise.forBodyPart(part);
    final minutes = list.fold(0, (s, e) => s + e.minutes);
    return Pressable(
      child: Material(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          side: const BorderSide(color: AppColors.border),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          onTap: () => Navigator.of(context).push(scopedRoute(context, WorkoutsScreen(bodyPart: part))),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                upper
                    ? const SoftIcon(icon: Icons.fitness_center_rounded)
                    : const SoftIcon(icon: Icons.directions_walk_rounded, color: AppColors.warn, background: AppColors.warnSoft),
                const SizedBox(height: 12),
                Text(upper ? 'Upper body' : 'Lower body', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                Text('${list.length} exercises · $minutes min', style: const TextStyle(fontSize: 12, color: AppColors.muted)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
