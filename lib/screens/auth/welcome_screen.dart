import 'package:flutter/material.dart';

import '../../core/motion.dart';
import '../../core/theme.dart';
import '../../models/exercise.dart';
import '../../widgets/pose_animation.dart';
import '../../widgets/ui.dart';
import 'login_screen.dart';
import 'signup_screen.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Entrance(child: _Brand()),
              const Expanded(
                child: Entrance(
                  delay: Duration(milliseconds: 100),
                  child: Center(child: FittedBox(fit: BoxFit.scaleDown, child: _Hero())),
                ),
              ),
              Entrance(
                delay: Motion.stagger(0, startMs: 200),
                child: Text('Your AI personal trainer', style: Theme.of(context).textTheme.displaySmall?.copyWith(fontSize: 32, height: 1.15)),
              ),
              const SizedBox(height: 12),
              Entrance(
                delay: Motion.stagger(1, startMs: 200),
                child: const Text(
                  'Point your camera. We count every rep and tell you when your form slips — no equipment, no coach needed.',
                  style: TextStyle(fontSize: 16, height: 1.5, color: AppColors.muted),
                ),
              ),
              const SizedBox(height: 24),
              Entrance(
                delay: Motion.stagger(2, startMs: 200),
                child: PrimaryButton(
                  label: 'Get started',
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SignUpScreen())),
                ),
              ),
              const SizedBox(height: 12),
              Entrance(
                delay: Motion.stagger(3, startMs: 200),
                child: SecondaryButton(
                  label: 'I already have an account',
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const LoginScreen())),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Brand extends StatelessWidget {
  const _Brand();

  @override
  Widget build(BuildContext context) => const Row(
        children: [
          SoftIcon(icon: Icons.fitness_center_rounded, color: AppColors.accent, background: AppColors.ink, size: 32),
          SizedBox(width: 8),
          Text('Fitness Tracker', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
        ],
      );
}

/// Animated stick figure doing squats inside a "scanner" circle, with
/// floating feedback chips — explains the product in one glance.
class _Hero extends StatefulWidget {
  const _Hero();

  @override
  State<_Hero> createState() => _HeroState();
}

class _HeroState extends State<_Hero> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 3200));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!Motion.reduced(context) && !_c.isAnimating) _c.repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 330,
      height: 300,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 280,
            height: 280,
            decoration: const BoxDecoration(color: AppColors.accentSoft, shape: BoxShape.circle),
            padding: const EdgeInsets.all(22),
            child: ClipOval(
              child: Container(
                color: Colors.white,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    const PoseLoop(kind: ExerciseKind.squat, color: AppColors.accent, size: Size(200, 214)),
                    Positioned.fill(
                      child: AnimatedBuilder(
                        animation: _c,
                        builder: (_, __) {
                          final t = _c.value < 0.5 ? _c.value * 2 : (1 - _c.value) * 2;
                          return Align(
                            alignment: Alignment(0, -1 + 2 * Curves.easeInOut.transform(t)),
                            child: Container(height: 2, color: AppColors.accent.withValues(alpha: 0.5)),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const Positioned(left: 0, top: 60, child: _FloatingChip(delay: 0, dark: false, label: 'Good form')),
          const Positioned(right: 0, bottom: 60, child: _FloatingChip(delay: 1200, dark: true, label: 'Rep 5 / 8')),
        ],
      ),
    );
  }
}

class _FloatingChip extends StatefulWidget {
  const _FloatingChip({required this.delay, required this.dark, required this.label});
  final int delay;
  final bool dark;
  final String label;

  @override
  State<_FloatingChip> createState() => _FloatingChipState();
}

class _FloatingChipState extends State<_FloatingChip> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(seconds: 3));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (Motion.reduced(context) || _c.isAnimating) return;
    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) _c.repeat(reverse: true);
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final chip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: widget.dark ? AppColors.ink : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: widget.dark ? null : Border.all(color: AppColors.border),
        boxShadow: const [BoxShadow(color: Color(0x140E1B2C), blurRadius: 18, offset: Offset(0, 6))],
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (!widget.dark) ...[
          const Icon(Icons.check_rounded, size: 16, color: AppColors.success),
          const SizedBox(width: 6),
        ],
        Text(widget.label,
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: widget.dark ? Colors.white : AppColors.ink)),
      ]),
    );
    return AnimatedBuilder(
      animation: _c,
      child: chip,
      builder: (_, child) => Transform.translate(
        offset: Offset(0, -8 * Curves.easeInOut.transform(_c.value)),
        child: child,
      ),
    );
  }
}
