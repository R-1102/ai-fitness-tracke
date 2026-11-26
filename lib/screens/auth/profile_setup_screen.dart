import 'package:flutter/material.dart';

import '../../core/motion.dart';
import '../../core/theme.dart';
import '../../models/exercise.dart';
import '../../models/user_profile.dart';
import '../../services/services.dart';
import '../../widgets/ui.dart';

/// Sign-up step 2: gender and fitness level (sets reps per set).
class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key, required this.profile});

  final UserProfile profile;

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  Gender? _gender;
  Level? _level;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _gender = widget.profile.gender;
    _level = widget.profile.level ?? Level.beginner;
  }

  Future<void> _save() async {
    setState(() => _busy = true);
    try {
      await userRepository.saveProfile(widget.profile.copyWith(gender: _gender, level: _level));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not save: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget stagger(int i, Widget child) => Entrance(delay: Motion.stagger(i), child: child);

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          children: [
            stagger(0, Row(children: [
              AppBackButton(tooltip: 'Cancel sign-up', icon: Icons.close_rounded, onPressed: () => authService.signOut()),
              const SizedBox(width: 14),
              const Expanded(child: StepProgress(step: 2, total: 2)),
            ])),
            const SizedBox(height: 20),
            stagger(1, Text('Personalise your plan', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontSize: 28))),
            const SizedBox(height: 6),
            stagger(1, const Text('Your level sets how many reps each set needs.', style: TextStyle(fontSize: 14, color: AppColors.muted))),
            const SizedBox(height: 20),
            stagger(2, const Text('Gender', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700))),
            const SizedBox(height: 10),
            stagger(2, GenderPicker(value: _gender, onChanged: (g) => setState(() => _gender = g))),
            const SizedBox(height: 20),
            stagger(3, const Text('Fitness level', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700))),
            const SizedBox(height: 10),
            stagger(3, LevelPicker(value: _level, onChanged: (l) => setState(() => _level = l))),
            const SizedBox(height: 24),
            stagger(4, PrimaryButton(
              label: 'Start training',
              busy: _busy,
              onPressed: _gender == null || _level == null ? null : _save,
            )),
          ],
        ),
      ),
    );
  }
}

class GenderPicker extends StatelessWidget {
  const GenderPicker({super.key, required this.value, required this.onChanged});
  final Gender? value;
  final ValueChanged<Gender> onChanged;

  @override
  Widget build(BuildContext context) {
    Widget option(Gender g, String label) {
      final sel = value == g;
      return Expanded(
        child: SelectableCard(
          selected: sel,
          onTap: () => onChanged(g),
          padding: EdgeInsets.zero,
          child: SizedBox(
            height: 128,
            child: Stack(
              children: [
                Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    AnimatedContainer(
                      duration: Motion.fast,
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(color: sel ? AppColors.accentSoft : AppColors.background, shape: BoxShape.circle),
                      child: Icon(Icons.person_outline_rounded, size: 34, color: sel ? AppColors.accent : AppColors.muted),
                    ),
                    const SizedBox(height: 10),
                    Text(label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                  ]),
                ),
                Positioned(
                  top: 10,
                  right: 10,
                  child: AnimatedScale(
                    scale: sel ? 1 : 0,
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOutBack,
                    child: Container(
                      width: 22,
                      height: 22,
                      decoration: const BoxDecoration(color: AppColors.accent, shape: BoxShape.circle),
                      child: const Icon(Icons.check_rounded, size: 14, color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Row(children: [
      option(Gender.female, 'Female'),
      const SizedBox(width: 12),
      option(Gender.male, 'Male'),
    ]);
  }
}

class LevelPicker extends StatelessWidget {
  const LevelPicker({super.key, required this.value, required this.onChanged});
  final Level? value;
  final ValueChanged<Level> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final (i, level) in Level.values.indexed) ...[
          if (i > 0) const SizedBox(height: 10),
          SelectableCard(
            selected: value == level,
            onTap: () => onChanged(level),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                _LevelBars(filled: i + 1, active: value == level),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(level.label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                    Text('${level.repsPerSet} reps × ${Level.setsPerWorkout} sets',
                        style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                  ]),
                ),
                AnimatedContainer(
                  duration: Motion.fast,
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: value == level ? AppColors.accent : const Color(0xFFC9D1DD),
                      width: value == level ? 7 : 2,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _LevelBars extends StatelessWidget {
  const _LevelBars({required this.filled, required this.active});
  final int filled;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final on = active ? AppColors.accent : AppColors.ink;
    return SizedBox(
      height: 22,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final (i, h) in const [8.0, 15.0, 22.0].indexed) ...[
            if (i > 0) const SizedBox(width: 3),
            AnimatedContainer(
              duration: Motion.fast,
              width: 5,
              height: h,
              decoration: BoxDecoration(
                color: i < filled ? on : const Color(0xFFD8DDE5),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
