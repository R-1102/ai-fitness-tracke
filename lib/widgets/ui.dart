import 'package:flutter/material.dart';

import '../core/motion.dart';
import '../core/theme.dart';

/// 44×44 white square button with a border (back, close, share…).
class SquareIconButton extends StatelessWidget {
  const SquareIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    this.onPressed,
    this.background = Colors.white,
    this.foreground = AppColors.ink,
    this.bordered = true,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final Color background;
  final Color foreground;
  final bool bordered;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      child: Material(
        color: background,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: bordered ? const BorderSide(color: AppColors.border) : BorderSide.none,
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onPressed,
          child: Tooltip(
            message: tooltip,
            child: SizedBox.square(dimension: 44, child: Icon(icon, size: 22, color: foreground)),
          ),
        ),
      ),
    );
  }
}

class AppBackButton extends StatelessWidget {
  const AppBackButton({super.key, this.onPressed, this.icon = Icons.chevron_left_rounded, this.tooltip = 'Back'});
  final VoidCallback? onPressed;
  final IconData icon;
  final String tooltip;

  @override
  Widget build(BuildContext context) => SquareIconButton(
        icon: icon,
        tooltip: tooltip,
        onPressed: onPressed ?? () => Navigator.of(context).maybePop(),
      );
}

/// Primary / secondary full-width buttons with press feedback.
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({super.key, required this.label, this.onPressed, this.icon, this.busy = false, this.color});

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool busy;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final child = busy
        ? const SizedBox.square(dimension: 22, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
        : Row(mainAxisSize: MainAxisSize.min, children: [
            if (icon != null) ...[Icon(icon, size: 20), const SizedBox(width: 8)],
            Text(label),
          ]);
    return Pressable(
      child: FilledButton(
        style: color == null ? null : FilledButton.styleFrom(backgroundColor: color),
        onPressed: busy ? null : onPressed,
        child: AnimatedSwitcher(duration: Motion.fast, child: KeyedSubtree(key: ValueKey('$busy$label'), child: child)),
      ),
    );
  }
}

class SecondaryButton extends StatelessWidget {
  const SecondaryButton({super.key, required this.label, this.onPressed, this.icon});
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => Pressable(
        child: OutlinedButton(
          onPressed: onPressed,
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            if (icon != null) ...[Icon(icon, size: 20), const SizedBox(width: 8)],
            Text(label),
          ]),
        ),
      );
}

/// Rounded tinted square holding an icon.
class SoftIcon extends StatelessWidget {
  const SoftIcon({super.key, required this.icon, this.color = AppColors.accent, this.background = AppColors.accentSoft, this.size = 44});
  final IconData icon;
  final Color color;
  final Color background;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(size * 0.32)),
        child: Icon(icon, color: color, size: size * 0.52),
      );
}

/// "Step 1 of 2" + animated progress bar.
class StepProgress extends StatelessWidget {
  const StepProgress({super.key, required this.step, required this.total});
  final int step;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Step $step of $total',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.muted)),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: Container(
            height: 6,
            color: AppColors.border,
            child: GrowBar(
              fraction: step / total,
              color: AppColors.accent,
              height: 6,
              delay: const Duration(milliseconds: 200),
            ),
          ),
        ),
      ],
    );
  }
}

/// iOS-style segmented control (level picker, gender…).
class SegmentedPill<T> extends StatelessWidget {
  const SegmentedPill({super.key, required this.options, required this.value, required this.onChanged});

  final List<(T value, String label)> options;
  final T value;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: AppColors.track, borderRadius: BorderRadius.circular(14)),
      child: Row(
        children: [
          for (final (v, label) in options)
            Expanded(
              child: Semantics(
                button: true,
                selected: v == value,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onChanged(v),
                  child: AnimatedContainer(
                    duration: Motion.fast,
                    curve: Curves.easeOut,
                    height: 42,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: v == value ? Colors.white : Colors.transparent,
                      borderRadius: BorderRadius.circular(11),
                      boxShadow: v == value
                          ? const [BoxShadow(color: Color(0x1F0E1B2C), blurRadius: 3, offset: Offset(0, 1))]
                          : null,
                    ),
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: v == value ? AppColors.ink : AppColors.muted,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// White card that gets an accent border when selected.
class SelectableCard extends StatelessWidget {
  const SelectableCard({super.key, required this.selected, required this.onTap, required this.child, this.padding});

  final bool selected;
  final VoidCallback onTap;
  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      scale: 0.98,
      child: Semantics(
        button: true,
        selected: selected,
        child: GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: Motion.fast,
            padding: padding ?? const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: selected ? const Color(0xFFF5F8FF) : Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: selected ? AppColors.accent : AppColors.border, width: 2),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// Small white card with a big number and a label.
class StatTile extends StatelessWidget {
  const StatTile({super.key, required this.value, required this.label, this.color, this.caption, this.center = false});

  final Widget value;
  final String label;
  final Color? color;
  final String? caption;
  final bool center;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: center ? CrossAxisAlignment.center : CrossAxisAlignment.start,
        children: [
          if (!center) Text(label, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
          DefaultTextStyle.merge(
            style: TextStyle(fontSize: center ? 20 : 24, fontWeight: FontWeight.w800, color: color ?? AppColors.ink),
            child: value,
          ),
          if (center) Text(label, style: const TextStyle(fontSize: 11, color: AppColors.muted)),
          if (caption != null)
            Text(caption!, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.success)),
        ],
      ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key, this.action, this.onAction});
  final String title;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Expanded(child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800))),
          if (action != null) TextButton(onPressed: onAction, child: Text(action!)),
        ],
      );
}

/// Light-blue card used for AI tips and insights.
class InsightCard extends StatelessWidget {
  const InsightCard({super.key, required this.text, this.title});
  final String text;
  final String? title;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.accentSoft, borderRadius: BorderRadius.circular(AppRadius.lg)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SoftIcon(icon: Icons.auto_awesome, color: Colors.white, background: AppColors.accent, size: 36),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (title != null) ...[
                  Text(title!, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                ],
                Text(text, style: const TextStyle(fontSize: 13, height: 1.45, color: AppColors.accentTextOnSoft)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class Pill extends StatelessWidget {
  const Pill(this.label, {super.key, this.background = Colors.white, this.foreground = AppColors.ink, this.bordered = true, this.icon});
  final String label;
  final Color background;
  final Color foreground;
  final bool bordered;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(10),
          border: bordered ? Border.all(color: AppColors.border) : null,
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (icon != null) ...[Icon(icon, size: 12, color: foreground), const SizedBox(width: 4)],
          Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: foreground)),
        ]),
      );
}

class InitialAvatar extends StatelessWidget {
  const InitialAvatar({super.key, required this.name, this.size = 44});
  final String name;
  final double size;

  @override
  Widget build(BuildContext context) {
    final initial = name.trim().isEmpty ? '?' : name.trim().characters.first.toUpperCase();
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: const BoxDecoration(color: AppColors.avatarBg, shape: BoxShape.circle),
      child: Text(initial,
          style: TextStyle(fontSize: size * 0.38, fontWeight: FontWeight.w800, color: AppColors.accentDark)),
    );
  }
}

/// Label + field, matching the design's form layout.
class LabeledField extends StatelessWidget {
  const LabeledField({super.key, required this.label, required this.child});
  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          child,
        ],
      );
}
