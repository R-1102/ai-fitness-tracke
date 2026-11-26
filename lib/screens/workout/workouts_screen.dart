import 'package:flutter/material.dart';

import '../../core/motion.dart';
import '../../core/theme.dart';
import '../../models/exercise.dart';
import '../../services/services.dart';
import '../../widgets/pose_animation.dart';
import '../../widgets/ui.dart';
import 'exercise_detail_screen.dart';

/// Exercise list with search + body-part filter. As a tab it starts on "All";
/// opened from a Home category tile it starts filtered by [bodyPart].
class WorkoutsScreen extends StatefulWidget {
  const WorkoutsScreen({super.key, this.bodyPart});

  final BodyPart? bodyPart;

  @override
  State<WorkoutsScreen> createState() => _WorkoutsScreenState();
}

class _WorkoutsScreenState extends State<WorkoutsScreen> {
  String _query = '';
  late BodyPart? _part = widget.bodyPart;

  @override
  Widget build(BuildContext context) {
    final results = Exercise.all
        .where((e) => _part == null || e.bodyParts.contains(_part))
        .where((e) => e.name.toLowerCase().contains(_query.toLowerCase()))
        .toList();
    final pushed = widget.bodyPart != null;

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          children: [
            Entrance(
              child: Row(children: [
                if (pushed) ...[const AppBackButton(), const SizedBox(width: 12)],
                Text('Workouts', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontSize: 26)),
              ]),
            ),
            const SizedBox(height: 16),
            Entrance(
              delay: Motion.stagger(1),
              child: TextField(
                decoration: const InputDecoration(
                  hintText: 'Search exercises',
                  prefixIcon: Icon(Icons.search_rounded, color: AppColors.muted),
                ),
                onChanged: (v) => setState(() => _query = v.trim()),
              ),
            ),
            const SizedBox(height: 16),
            Entrance(
              delay: Motion.stagger(2),
              child: Wrap(
                spacing: 8,
                children: [
                  for (final (part, label) in const [(null, 'All'), (BodyPart.upper, 'Upper body'), (BodyPart.lower, 'Lower body')])
                    _FilterChip(label: label, selected: _part == part, onTap: () => setState(() => _part = part)),
                ],
              ),
            ),
            const SizedBox(height: 16),
            AnimatedSwitcher(
              duration: Motion.fast,
              child: results.isEmpty
                  ? Padding(
                      key: const ValueKey('empty'),
                      padding: const EdgeInsets.only(top: 40),
                      child: Text('No exercises match “$_query”.',
                          textAlign: TextAlign.center, style: const TextStyle(color: AppColors.muted)),
                    )
                  : Column(
                      key: ValueKey('${_part?.name}$_query'),
                      children: [
                        for (final (i, e) in results.indexed)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Entrance(delay: Motion.stagger(i, startMs: 140), child: ExerciseCard(exercise: e)),
                          ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      child: Semantics(
        button: true,
        selected: selected,
        child: GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: Motion.fast,
            height: 38,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected ? AppColors.ink : Colors.white,
              borderRadius: BorderRadius.circular(19),
              border: Border.all(color: selected ? AppColors.ink : AppColors.border),
            ),
            child: Text(label,
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: selected ? Colors.white : AppColors.ink)),
          ),
        ),
      ),
    );
  }
}

class ExerciseCard extends StatelessWidget {
  const ExerciseCard({super.key, required this.exercise});
  final Exercise exercise;

  @override
  Widget build(BuildContext context) {
    final e = exercise;
    return Pressable(
      scale: 0.98,
      child: Material(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          side: const BorderSide(color: AppColors.border),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          onTap: () => Navigator.of(context).push(scopedRoute(context, ExerciseDetailScreen(exercise: e))),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                ExerciseGlyph(exercise: e),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(e.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 2),
                      Text('${e.muscles} · ${e.minutes} min', style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                      const SizedBox(height: 6),
                      Pill(e.checkLabel,
                          icon: Icons.auto_awesome,
                          background: AppColors.accentSoft,
                          foreground: AppColors.accentDark,
                          bordered: false),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, color: AppColors.subtle),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
