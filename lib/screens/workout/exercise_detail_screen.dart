import 'package:flutter/material.dart';

import '../../core/motion.dart';
import '../../core/theme.dart';
import '../../models/exercise.dart';
import '../../services/services.dart';
import '../../widgets/pose_animation.dart';
import '../../widgets/ui.dart';
import 'live_workout_screen.dart';

class ExerciseDetailScreen extends StatefulWidget {
  const ExerciseDetailScreen({super.key, required this.exercise});

  final Exercise exercise;

  @override
  State<ExerciseDetailScreen> createState() => _ExerciseDetailScreenState();
}

class _ExerciseDetailScreenState extends State<ExerciseDetailScreen> {
  Level? _level;

  @override
  Widget build(BuildContext context) {
    final e = widget.exercise;
    final level = _level ??= ProfileScope.of(context).levelOrDefault;
    Widget stagger(int i, Widget child) => Entrance(delay: Motion.stagger(i, startMs: 80), child: child);

    return Scaffold(
      body: Column(
        children: [
          Expanded(
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(child: _Header(exercise: e)),
                SliverToBoxAdapter(
                  child: Transform.translate(
                    offset: const Offset(0, -24),
                    child: Container(
                      decoration: const BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.sheet)),
                      ),
                      padding: const EdgeInsets.fromLTRB(20, 22, 20, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          stagger(0, Text(e.name, style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontSize: 28))),
                          const SizedBox(height: 10),
                          stagger(0, Wrap(spacing: 6, runSpacing: 6, children: [
                            Pill(e.muscles),
                            Pill('~${e.minutes} min'),
                            const Pill('No equipment needed'),
                          ])),
                          const SizedBox(height: 16),
                          stagger(1, SegmentedPill<Level>(
                            options: [for (final l in Level.values) (l, l.label)],
                            value: level,
                            onChanged: (l) => setState(() => _level = l),
                          )),
                          const SizedBox(height: 8),
                          stagger(1, AnimatedSwitcher(
                            duration: Motion.fast,
                            child: Text(
                              '${level.repsPerSet} reps × ${Level.setsPerWorkout} sets · 15 s rest between sets',
                              key: ValueKey(level),
                              style: const TextStyle(fontSize: 13, color: AppColors.muted),
                            ),
                          )),
                          const SizedBox(height: 16),
                          stagger(2, Text(e.description, style: const TextStyle(fontSize: 14, height: 1.5, color: Color(0xFF33415A)))),
                          const SizedBox(height: 16),
                          stagger(3, _AiSteps(steps: e.aiSteps)),
                          const SizedBox(height: 12),
                          stagger(4, Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            decoration: BoxDecoration(color: AppColors.accentSoft, borderRadius: BorderRadius.circular(AppRadius.md)),
                            child: Row(children: [
                              const Icon(Icons.smartphone_rounded, color: AppColors.accentDark, size: 26),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(e.cameraTip,
                                    style: const TextStyle(fontSize: 13, height: 1.4, color: AppColors.accentTextOnSoft)),
                              ),
                            ]),
                          )),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: Entrance(
                delay: Motion.stagger(5, startMs: 80),
                child: PrimaryButton(
                  label: 'Start workout',
                  icon: Icons.play_arrow_rounded,
                  onPressed: () => Navigator.of(context).push(scopedRoute(context, LiveWorkoutScreen(exercise: e, level: level))),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.exercise});
  final Exercise exercise;

  @override
  Widget build(BuildContext context) {
    final style = exercise.style;
    return Container(
      height: 274,
      color: style.tint,
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          Positioned(
            bottom: -140,
            child: Container(width: 320, height: 320, decoration: BoxDecoration(color: style.halo, shape: BoxShape.circle)),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 32),
            child: PoseLoop(kind: exercise.kind, color: style.ink, headFill: style.tint, stroke: 6, size: const Size(170, 200)),
          ),
          const SafeArea(
            child: Align(
              alignment: Alignment.topLeft,
              child: Padding(padding: EdgeInsets.fromLTRB(20, 12, 20, 0), child: AppBackButton()),
            ),
          ),
        ],
      ),
    );
  }
}

class _AiSteps extends StatelessWidget {
  const _AiSteps({required this.steps});
  final List<(String, String)> steps;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('How the AI checks you', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
            for (final (i, (title, detail)) in steps.indexed) ...[
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 26,
                    height: 26,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(color: AppColors.accentSoft, shape: BoxShape.circle),
                    child: Text('${i + 1}',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.accentDark)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text.rich(
                      TextSpan(children: [
                        TextSpan(text: '$title ', style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.ink)),
                        TextSpan(text: detail),
                      ]),
                      style: const TextStyle(fontSize: 13, height: 1.45, color: Color(0xFF33415A)),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
