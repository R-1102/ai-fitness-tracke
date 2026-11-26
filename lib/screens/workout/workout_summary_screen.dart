import 'package:flutter/material.dart';

import '../../core/motion.dart';
import '../../core/theme.dart';
import '../../ml/workout_engine.dart' show SetResult;
import '../../models/stats.dart';
import '../../models/workout_session.dart';
import '../../services/services.dart';
import '../../widgets/ui.dart';

class WorkoutSummaryScreen extends StatelessWidget {
  const WorkoutSummaryScreen({super.key, required this.session, this.saved = true, this.fromWorkout = false});

  final WorkoutSession session;
  final bool saved;

  /// True right after a workout (shows "Done"); false when opened from history.
  final bool fromWorkout;

  /// Badge text, or null: first time doing this exercise or a new best accuracy.
  String? _badge(List<WorkoutSession> history) {
    if (session.totalReps == 0) return null;
    final earlier = history.where((s) => s.id != session.id && s.exerciseId == session.exerciseId && s.createdAt.isBefore(session.createdAt)).toList();
    if (earlier.isEmpty) return 'First time!';
    final best = WorkoutStats(earlier).bestAccuracy(session.exerciseId);
    return session.accuracy > best ? 'Personal best' : null;
  }

  @override
  Widget build(BuildContext context) {
    final history = SessionsScope.of(context);
    final badge = _badge(history);
    final d = session.createdAt;
    final today = DateUtils.isSameDay(d, DateTime.now());
    final dateLabel = today ? 'Today' : '${d.day}/${d.month}/${d.year}';
    final mins = session.duration.inSeconds ~/ 60, secs = session.duration.inSeconds % 60;
    final fresh = fromWorkout;
    Widget stagger(int i, Widget child) => Entrance(delay: Motion.stagger(i, stepMs: 70), child: child);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                children: [
                  stagger(0, Row(children: [
                    Expanded(
                      child: Text('${session.exercise.name} · ${session.level.label} · $dateLabel',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.muted)),
                    ),
                    if (!fresh) const AppBackButton(),
                  ])),
                  const SizedBox(height: 12),
                  stagger(1, Column(children: [
                    SizedBox(
                      width: 170,
                      height: 140,
                      child: Stack(
                        clipBehavior: Clip.none,
                        alignment: Alignment.center,
                        children: [
                          AnimatedRing(
                            value: session.accuracy,
                            size: 132,
                            stroke: 12,
                            color: AppColors.accent,
                            trackColor: AppColors.border,
                            delay: const Duration(milliseconds: 200),
                            child: Column(mainAxisSize: MainAxisSize.min, children: [
                              CountUp(
                                value: session.accuracy * 100,
                                delay: const Duration(milliseconds: 200),
                                format: (v) => '${v.round()}%',
                                style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w800),
                              ),
                              const Text('form accuracy', style: TextStyle(fontSize: 11, color: AppColors.muted)),
                            ]),
                          ),
                          if (badge != null) Positioned(right: -6, top: -2, child: _Badge(label: badge)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(session.totalReps == 0 ? 'Workout ended' : 'Workout complete!',
                        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
                  ])),
                  const SizedBox(height: 16),
                  stagger(2, Row(children: [
                    Expanded(child: StatTile(center: true, label: 'good reps', color: AppColors.success, value: CountUp(value: session.correctReps, delay: const Duration(milliseconds: 300)))),
                    const SizedBox(width: 8),
                    Expanded(child: StatTile(center: true, label: 'to fix', color: AppColors.warn, value: CountUp(value: session.wrongReps, delay: const Duration(milliseconds: 300)))),
                    const SizedBox(width: 8),
                    Expanded(child: StatTile(center: true, label: 'minutes', value: Text('$mins:${secs.toString().padLeft(2, '0')}'))),
                    const SizedBox(width: 8),
                    Expanded(child: StatTile(center: true, label: 'kcal', value: CountUp(value: session.calories, delay: const Duration(milliseconds: 300)))),
                  ])),
                  if (session.sets.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    stagger(3, _SetsCard(sets: session.sets)),
                  ],
                  const SizedBox(height: 16),
                  stagger(4, InsightCard(text: Insights.session(session))),
                  if (!saved) ...[
                    const SizedBox(height: 12),
                    const Text('No reps were detected, so this workout was not saved.',
                        textAlign: TextAlign.center, style: TextStyle(color: AppColors.muted)),
                  ],
                ],
              ),
            ),
            if (fresh)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
                child: Entrance(
                  delay: Motion.stagger(5, stepMs: 70),
                  child: PrimaryButton(label: 'Done', onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final reduced = Motion.reduced(context);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: reduced ? 1 : 0, end: 1),
      duration: const Duration(milliseconds: 1700),
      curve: const Interval(0.65, 1, curve: Curves.elasticOut),
      builder: (_, v, child) => Transform.scale(scale: v, child: Transform.rotate(angle: (1 - v) * -0.3, child: child)),
      child: Container(
        height: 28,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        alignment: Alignment.center,
        decoration: BoxDecoration(color: AppColors.ink, borderRadius: BorderRadius.circular(14)),
        child: Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white)),
      ),
    );
  }
}

class _SetsCard extends StatelessWidget {
  const _SetsCard({required this.sets});
  final List<SetResult> sets;

  @override
  Widget build(BuildContext context) {
    final maxTotal = sets.fold(1, (m, s) => s.correct + s.wrong > m ? s.correct + s.wrong : m);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Sets', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
            for (final (i, s) in sets.indexed) ...[
              const SizedBox(height: 12),
              Row(children: [
                SizedBox(width: 48, child: Text('Set ${i + 1}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700))),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(5),
                    child: Container(
                      height: 10,
                      color: AppColors.divider,
                      child: _SplitBar(set: s, maxTotal: maxTotal, delay: Duration(milliseconds: 350 + i * 120)),
                    ),
                  ),
                ),
                SizedBox(
                  width: 80,
                  child: Text(
                    '${s.correct} good${s.wrong > 0 ? ' · ${s.wrong} fix' : ''}',
                    textAlign: TextAlign.right,
                    style: const TextStyle(fontSize: 12, color: AppColors.muted),
                  ),
                ),
              ]),
            ],
          ],
        ),
      ),
    );
  }
}

/// Bar that grows in, split into good (blue) and flagged (orange) reps.
class _SplitBar extends StatefulWidget {
  const _SplitBar({required this.set, required this.maxTotal, required this.delay});
  final SetResult set;
  final int maxTotal;
  final Duration delay;

  @override
  State<_SplitBar> createState() => _SplitBarState();
}

class _SplitBarState extends State<_SplitBar> {
  bool _go = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(widget.delay, () {
      if (mounted) setState(() => _go = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.set;
    final target = (s.correct + s.wrong) / widget.maxTotal;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: _go || Motion.reduced(context) ? target : 0),
      duration: const Duration(milliseconds: 900),
      curve: Motion.curve,
      builder: (_, v, __) => FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: v,
        child: Row(children: [
          if (s.correct > 0) Expanded(flex: s.correct, child: Container(color: AppColors.accent)),
          if (s.wrong > 0) Expanded(flex: s.wrong, child: Container(color: AppColors.warn)),
        ]),
      ),
    );
  }
}
