import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Motion spec (matches the design canvas):
///  • screen enter: fade + 16 px rise, 550 ms, staggered ~60 ms per block
///  • rings / bars fill from 0 (1.2 s), numbers count up
///  • buttons scale to 97 % on press
///  • everything is skipped when the OS "reduce motion" setting is on
abstract final class Motion {
  static const enter = Duration(milliseconds: 550);
  static const fill = Duration(milliseconds: 1200);
  static const fast = Duration(milliseconds: 200);
  static const curve = Cubic(0.2, 0.8, 0.2, 1);

  static bool reduced(BuildContext context) => MediaQuery.maybeOf(context)?.disableAnimations ?? false;

  /// Delay for the n-th block in a staggered list.
  static Duration stagger(int index, {int stepMs = 60, int startMs = 0}) =>
      Duration(milliseconds: startMs + index * stepMs);
}

/// Android page transition: new page fades in while rising slightly.
class FadeSlidePageTransitionsBuilder extends PageTransitionsBuilder {
  const FadeSlidePageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final curved = CurvedAnimation(parent: animation, curve: Motion.curve, reverseCurve: Curves.easeIn);
    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween(begin: const Offset(0, 0.04), end: Offset.zero).animate(curved),
        child: child,
      ),
    );
  }
}

/// Fades + rises its child into place after [delay].
class Entrance extends StatefulWidget {
  const Entrance({super.key, required this.child, this.delay = Duration.zero, this.offset = 16});

  final Widget child;
  final Duration delay;
  final double offset;

  @override
  State<Entrance> createState() => _EntranceState();
}

class _EntranceState extends State<Entrance> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: Motion.enter);
  late final Animation<double> _t = CurvedAnimation(parent: _c, curve: Motion.curve);
  Timer? _timer;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (Motion.reduced(context)) {
      _c.value = 1;
    } else {
      _timer = Timer(widget.delay, () {
        if (mounted) _c.forward();
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _t,
      child: widget.child,
      builder: (context, child) => Opacity(
        opacity: _t.value,
        child: Transform.translate(offset: Offset(0, widget.offset * (1 - _t.value)), child: child),
      ),
    );
  }
}

/// Scales its child to 97 % while pressed. Uses a Listener so it never
/// steals taps from the button inside.
class Pressable extends StatefulWidget {
  const Pressable({super.key, required this.child, this.scale = 0.97});

  final Widget child;
  final double scale;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;

  void _set(bool v) {
    if (_down != v) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) => _set(true),
      onPointerUp: (_) => _set(false),
      onPointerCancel: (_) => _set(false),
      child: AnimatedScale(
        scale: _down && !Motion.reduced(context) ? widget.scale : 1,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

/// Circular progress ring that fills from 0 to [value] (0..1).
class AnimatedRing extends StatelessWidget {
  const AnimatedRing({
    super.key,
    required this.value,
    required this.size,
    required this.stroke,
    required this.color,
    required this.trackColor,
    this.delay = Duration.zero,
    this.child,
  });

  final double value;
  final double size;
  final double stroke;
  final Color color;
  final Color trackColor;
  final Duration delay;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final target = value.clamp(0.0, 1.0);
    return SizedBox.square(
      dimension: size,
      child: _Delayed(
        delay: delay,
        builder: (started) => TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: started || Motion.reduced(context) ? target : 0),
          duration: Motion.reduced(context) ? Duration.zero : Motion.fill,
          curve: Motion.curve,
          builder: (context, v, child) => CustomPaint(
            painter: _RingPainter(v, stroke, color, trackColor),
            child: child,
          ),
          child: Center(child: child),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.progress, this.stroke, this.color, this.track);
  final double progress, stroke;
  final Color color, track;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final r = rect.deflate(stroke / 2);
    final base = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = track;
    canvas.drawArc(r, 0, math.pi * 2, false, base);
    if (progress <= 0) return;
    canvas.drawArc(
      r,
      -math.pi / 2,
      math.pi * 2 * progress,
      false,
      base
        ..color = color
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.progress != progress || old.color != color;
}

/// Number that counts up from 0 to [value].
class CountUp extends StatelessWidget {
  const CountUp({super.key, required this.value, this.style, this.format, this.delay = Duration.zero});

  final num value;
  final TextStyle? style;
  final String Function(double v)? format;
  final Duration delay;

  @override
  Widget build(BuildContext context) {
    final fmt = format ?? (double v) => v.round().toString();
    if (Motion.reduced(context)) return Text(fmt(value.toDouble()), style: style);
    return _Delayed(
      delay: delay,
      builder: (started) => TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: started ? value.toDouble() : 0),
        duration: Motion.fill,
        curve: Curves.easeOutCubic,
        builder: (context, v, _) => Text(
          fmt(v),
          style: (style ?? const TextStyle()).copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
        ),
      ),
    );
  }
}

/// Horizontal bar that grows to [fraction] of the available width.
class GrowBar extends StatelessWidget {
  const GrowBar({super.key, required this.fraction, required this.color, this.height = 10, this.delay = Duration.zero});

  final double fraction;
  final Color color;
  final double height;
  final Duration delay;

  @override
  Widget build(BuildContext context) {
    return _Delayed(
      delay: delay,
      builder: (started) => TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: started || Motion.reduced(context) ? fraction.clamp(0.0, 1.0) : 0),
        duration: Motion.reduced(context) ? Duration.zero : const Duration(milliseconds: 900),
        curve: Motion.curve,
        builder: (context, v, _) => FractionallySizedBox(
          alignment: Alignment.centerLeft,
          widthFactor: v,
          child: Container(height: height, color: color),
        ),
      ),
    );
  }
}

/// A small dot with an expanding "live" pulse behind it.
class PulseDot extends StatefulWidget {
  const PulseDot({super.key, this.color = const Color(0xFF0E9F6E), this.size = 8});
  final Color color;
  final double size;

  @override
  State<PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<PulseDot> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dot = Container(
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle),
    );
    if (Motion.reduced(context)) return dot;
    return SizedBox.square(
      dimension: widget.size,
      child: Stack(clipBehavior: Clip.none, children: [
        AnimatedBuilder(
          animation: _c,
          builder: (_, __) => Transform.scale(
            scale: 1 + 1.6 * _c.value,
            child: Opacity(opacity: 0.7 * (1 - _c.value), child: dot),
          ),
        ),
        dot,
      ]),
    );
  }
}

/// Calls [builder] with `false` first and `true` after [delay].
class _Delayed extends StatefulWidget {
  const _Delayed({required this.delay, required this.builder});
  final Duration delay;
  final Widget Function(bool started) builder;

  @override
  State<_Delayed> createState() => _DelayedState();
}

class _DelayedState extends State<_Delayed> {
  bool _started = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(widget.delay, () {
      if (mounted) setState(() => _started = true);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(_started);
}
