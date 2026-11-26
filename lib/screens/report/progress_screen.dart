import 'package:flutter/material.dart';

import '../../core/motion.dart';
import '../../core/theme.dart';
import '../../models/stats.dart';
import '../../models/workout_session.dart';
import '../../services/services.dart';
import '../../widgets/pose_animation.dart';
import '../../widgets/ui.dart';
import '../workout/workout_summary_screen.dart';

class ProgressScreen extends StatefulWidget {
  const ProgressScreen({super.key});

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> {
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);

  static const _months = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];

  void _shift(int delta) => setState(() => _month = DateTime(_month.year, _month.month + delta));

  @override
  Widget build(BuildContext context) {
    final history = SessionsScope.of(context);
    final all = WorkoutStats(history);
    final month = all.month(_month);
    final prev = all.month(DateTime(_month.year, _month.month - 1));
    final now = DateTime.now();
    final isCurrent = _month.year == now.year && _month.month == now.month;
    final diff = ((month.accuracy - prev.accuracy) * 100).round();
    Widget stagger(int i, Widget child) => Entrance(delay: Motion.stagger(i, stepMs: 70), child: child);

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        children: [
          stagger(0, Row(children: [
            Expanded(child: Text('Progress', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontSize: 26))),
            _MonthButton(icon: Icons.chevron_left_rounded, tooltip: 'Previous month', onTap: () => _shift(-1)),
            SizedBox(
              width: 96,
              child: AnimatedSwitcher(
                duration: Motion.fast,
                child: Text(
                  _months[_month.month - 1],
                  key: ValueKey(_month),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                ),
              ),
            ),
            _MonthButton(icon: Icons.chevron_right_rounded, tooltip: 'Next month', onTap: isCurrent ? null : () => _shift(1)),
          ])),
          const SizedBox(height: 16),
          stagger(1, _CalendarCard(key: ValueKey(_month), month: _month, repsByDay: all.repsByDay(_month))),
          const SizedBox(height: 16),
          stagger(2, Row(children: [
            Expanded(
              child: StatTile(
                label: 'Form accuracy',
                value: CountUp(
                  key: ValueKey('acc$_month'),
                  value: month.accuracy * 100,
                  format: (v) => '${v.round()}%',
                  delay: const Duration(milliseconds: 250),
                ),
                caption: prev.workouts == 0 || month.workouts == 0 ? null : '${diff >= 0 ? '+' : ''}$diff% vs last month',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: StatTile(
                label: 'Good reps',
                value: CountUp(key: ValueKey('reps$_month'), value: month.correctReps, delay: const Duration(milliseconds: 250)),
                caption: '${month.workouts} workouts',
              ),
            ),
          ])),
          const SizedBox(height: 20),
          stagger(3, const SectionHeader('Recent workouts')),
          const SizedBox(height: 8),
          if (history.isEmpty)
            stagger(4, const _Empty())
          else
            for (final (i, s) in history.take(10).indexed)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Entrance(delay: Motion.stagger(i, startMs: 280, stepMs: 50), child: _SessionRow(session: s)),
              ),
        ],
      ),
    );
  }
}

class _MonthButton extends StatelessWidget {
  const _MonthButton({required this.icon, required this.tooltip, this.onTap});
  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Opacity(
        opacity: onTap == null ? 0.4 : 1,
        child: SquareIconButton(icon: icon, tooltip: tooltip, onPressed: onTap),
      );
}

/// Month heat-map: darker = more correct reps that day.
class _CalendarCard extends StatelessWidget {
  const _CalendarCard({super.key, required this.month, required this.repsByDay});
  final DateTime month;
  final Map<int, int> repsByDay;

  static const _shades = [Color(0xFFEEF1F6), Color(0xFFBFD1FF), Color(0xFF7FA3FF), AppColors.accent];

  static int _level(int reps) => reps == 0 ? 0 : reps <= 20 ? 1 : reps <= 50 ? 2 : 3;

  @override
  Widget build(BuildContext context) {
    final daysInMonth = DateUtils.getDaysInMonth(month.year, month.month);
    final lead = DateTime(month.year, month.month, 1).weekday % 7; // Sunday first
    final today = DateUtils.dateOnly(DateTime.now());
    final cells = lead + daysInMonth;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(children: [
              for (final l in const ['S', 'M', 'T', 'W', 'T', 'F', 'S'])
                Expanded(child: Text(l, textAlign: TextAlign.center, style: const TextStyle(fontSize: 11, color: AppColors.muted))),
            ]),
            const SizedBox(height: 10),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: cells,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                mainAxisSpacing: 6,
                crossAxisSpacing: 6,
                mainAxisExtent: 34,
              ),
              itemBuilder: (context, i) {
                if (i < lead) return const SizedBox.shrink();
                final day = i - lead + 1;
                final date = DateTime(month.year, month.month, day);
                final future = date.isAfter(today);
                final level = future ? 0 : _level(repsByDay[day] ?? 0);
                return Entrance(
                  delay: Duration(milliseconds: 100 + i * 12),
                  offset: 6,
                  child: Container(
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: future ? Colors.transparent : _shades[level],
                      borderRadius: BorderRadius.circular(9),
                      border: date == today ? Border.all(color: AppColors.ink, width: 1.5) : null,
                    ),
                    child: Text(
                      '$day',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: future ? AppColors.subtle : (level == 3 ? Colors.white : AppColors.ink),
                      ),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                const Text('Less', style: TextStyle(fontSize: 11, color: AppColors.muted)),
                for (final c in _shades) ...[
                  const SizedBox(width: 6),
                  Container(width: 12, height: 12, decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(3))),
                ],
                const SizedBox(width: 6),
                const Text('More', style: TextStyle(fontSize: 11, color: AppColors.muted)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SessionRow extends StatelessWidget {
  const _SessionRow({required this.session});
  final WorkoutSession session;

  @override
  Widget build(BuildContext context) {
    final s = session;
    final d = s.createdAt;
    final now = DateTime.now();
    final days = DateUtils.dateOnly(now).difference(DateUtils.dateOnly(d)).inDays;
    final when = days == 0 ? 'Today' : days == 1 ? 'Yesterday' : '${d.day}/${d.month}';
    return Pressable(
      scale: 0.98,
      child: Material(
        color: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md), side: const BorderSide(color: AppColors.border)),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.md),
          onTap: () => Navigator.of(context).push(scopedRoute(context, WorkoutSummaryScreen(session: s))),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(children: [
              ExerciseGlyph(exercise: s.exercise, size: 40),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(s.exercise.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                  Text('$when · ${s.totalReps} reps · ${(s.duration.inSeconds / 60).ceil()} min',
                      style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                ]),
              ),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text('${(s.accuracy * 100).round()}%', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
                const Text('form', style: TextStyle(fontSize: 11, color: AppColors.muted)),
              ]),
            ]),
          ),
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty();

  @override
  Widget build(BuildContext context) => const Card(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(children: [
            SoftIcon(icon: Icons.insights_rounded, size: 56),
            SizedBox(height: 12),
            Text('No workouts yet', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            SizedBox(height: 4),
            Text('Finish your first workout to see your progress here.',
                textAlign: TextAlign.center, style: TextStyle(color: AppColors.muted)),
          ]),
        ),
      );
}
