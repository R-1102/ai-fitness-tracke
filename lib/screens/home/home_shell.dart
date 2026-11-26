import 'package:flutter/material.dart';

import '../../core/motion.dart';
import '../../core/theme.dart';
import '../../models/workout_session.dart';
import '../../services/services.dart';
import '../profile/profile_screen.dart';
import '../report/progress_screen.dart';
import '../workout/workouts_screen.dart';
import 'home_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;
  late final Stream<List<WorkoutSession>> _sessions =
      userRepository.watchSessions(authService.currentUser!.uid);

  void _goTo(int index) => setState(() => _index = index);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<WorkoutSession>>(
      stream: _sessions,
      builder: (context, snap) {
        // Each tab is keyed by the selected index so its entrance animation
        // replays when you switch to it.
        final page = switch (_index) {
          0 => HomeScreen(key: const ValueKey(0), onOpenWorkouts: () => _goTo(1)),
          1 => const WorkoutsScreen(key: ValueKey(1)),
          2 => const ProgressScreen(key: ValueKey(2)),
          _ => const ProfileScreen(key: ValueKey(3)),
        };
        return SessionsScope(
          sessions: snap.data ?? const [],
          child: Scaffold(
            body: AnimatedSwitcher(
              duration: Motion.reduced(context) ? Duration.zero : const Duration(milliseconds: 220),
              child: page,
            ),
            bottomNavigationBar: AppNavBar(index: _index, onSelect: _goTo),
          ),
        );
      },
    );
  }
}

class AppNavBar extends StatelessWidget {
  const AppNavBar({super.key, required this.index, required this.onSelect});
  final int index;
  final ValueChanged<int> onSelect;

  static const _items = [
    (Icons.home_outlined, Icons.home_rounded, 'Home'),
    (Icons.fitness_center_outlined, Icons.fitness_center_rounded, 'Workouts'),
    (Icons.bar_chart_outlined, Icons.bar_chart_rounded, 'Progress'),
    (Icons.person_outline_rounded, Icons.person_rounded, 'Profile'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            children: [
              for (final (i, (icon, activeIcon, label)) in _items.indexed)
                Expanded(
                  child: Semantics(
                    selected: i == index,
                    button: true,
                    label: label,
                    child: InkResponse(
                      onTap: () => onSelect(i),
                      radius: 40,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          AnimatedScale(
                            scale: i == index ? 1.1 : 1,
                            duration: Motion.fast,
                            child: Icon(i == index ? activeIcon : icon, color: i == index ? AppColors.accent : AppColors.muted),
                          ),
                          const SizedBox(height: 4),
                          AnimatedDefaultTextStyle(
                            duration: Motion.fast,
                            style: TextStyle(
                              fontFamily: kFont,
                              fontSize: 11,
                              fontWeight: i == index ? FontWeight.w700 : FontWeight.w500,
                              color: i == index ? AppColors.accent : AppColors.muted,
                            ),
                            child: Text(label),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
