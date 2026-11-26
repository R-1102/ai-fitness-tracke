import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../../core/motion.dart';
import '../../core/theme.dart';
import '../../ml/camera_pose_source.dart';
import '../../ml/form_analyzers.dart';
import '../../ml/model_loader.dart';
import '../../ml/pose_frame.dart';
import '../../ml/workout_engine.dart';
import '../../models/exercise.dart';
import '../../models/workout_session.dart';
import '../../services/services.dart';
import '../../services/voice_coach.dart';
import '../../widgets/pose_painter.dart';
import '../../widgets/ui.dart';
import 'workout_summary_screen.dart';

/// Real-time workout: camera -> ML Kit pose -> trained models -> rep counter.
class LiveWorkoutScreen extends StatefulWidget {
  const LiveWorkoutScreen({super.key, required this.exercise, required this.level});

  final Exercise exercise;
  final Level level;

  @override
  State<LiveWorkoutScreen> createState() => _LiveWorkoutScreenState();
}

class _LiveWorkoutScreenState extends State<LiveWorkoutScreen> with WidgetsBindingObserver {
  final _poseSource = CameraPoseSource();
  CameraController? _controller;
  List<CameraDescription> _cameras = const [];
  CameraLensDirection _lens = CameraLensDirection.front;

  PoseWorkoutPipeline? _pipeline;
  WorkoutState? _state;
  PoseFrame? _frame;
  Timer? _ticker;
  VoiceCoach? _coach;
  bool _processing = false;
  bool _finished = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _setup());
  }

  Future<void> _setup() async {
    final profile = ProfileScope.of(context);
    _coach = VoiceCoach(enabled: profile.voiceCoaching);
    unawaited(_coach!.init());
    try {
      _pipeline = await ModelLoader.instance.pipelineFor(widget.exercise, widget.level);
      _cameras = await availableCameras();
      await _startCamera();
      _pipeline!.engine.start();
      _coach!.say('Get ready');
      _ticker = Timer.periodic(const Duration(milliseconds: 250), (_) => _onTick());
    } on CameraException catch (e) {
      setState(() => _error = e.code == 'CameraAccessDenied'
          ? 'Camera permission is required. Enable it in Settings.'
          : 'Camera error: ${e.description}');
    } catch (e) {
      setState(() => _error = 'Could not start workout: $e');
    }
  }

  Future<void> _startCamera() async {
    if (_cameras.isEmpty) throw CameraException('NoCamera', 'No camera found on this device');
    final camera = _cameras.firstWhere((c) => c.lensDirection == _lens, orElse: () => _cameras.first);
    final controller = CameraController(
      camera,
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup: CameraPoseSource.imageFormatGroup,
    );
    _controller = controller;
    await controller.initialize();
    await controller.startImageStream(_onImage);
    if (mounted) setState(() {});
  }

  Future<void> _stopCamera() async {
    final c = _controller;
    _controller = null;
    if (c == null) return;
    if (c.value.isStreamingImages) await c.stopImageStream();
    await c.dispose();
  }

  Future<void> _switchCamera() async {
    _lens = _lens == CameraLensDirection.front ? CameraLensDirection.back : CameraLensDirection.front;
    await _stopCamera();
    await _startCamera();
  }

  void _onTick() {
    final pipeline = _pipeline;
    if (pipeline == null || _finished) return;
    _apply(pipeline.engine.tick());
  }

  Future<void> _onImage(CameraImage image) async {
    final controller = _controller;
    final pipeline = _pipeline;
    if (_processing || controller == null || pipeline == null || _finished) return;
    _processing = true;
    try {
      final frame = await _poseSource.detect(image, controller);
      final state = pipeline.process(frame);
      if (!mounted) return;
      _frame = frame;
      _apply(state);
    } catch (e) {
      debugPrint('Frame error: $e');
    } finally {
      _processing = false;
    }
  }

  /// Updates the UI and speaks cues when something changed.
  void _apply(WorkoutState next) {
    final prev = _state;
    final coach = _coach;
    if (coach != null && prev != null) {
      if (next.correctReps > prev.correctReps) coach.rep(next.reps == 0 ? next.targetReps : next.reps);
      if (next.wrongReps > prev.wrongReps) coach.cue(next.feedback ?? 'Check your form');
      if (prev.phase != next.phase) {
        switch (next.phase) {
          case WorkoutPhase.active:
            coach.say(prev.phase == WorkoutPhase.countdown ? 'Go!' : 'Next set. Go!', interrupt: false);
          case WorkoutPhase.rest:
            coach.say('Set complete. Rest ${next.secondsLeft} seconds.', interrupt: false);
          case WorkoutPhase.completed:
            coach.say('Workout complete. Great job!', interrupt: false);
          case WorkoutPhase.countdown:
            break;
        }
      }
    }
    if (mounted) setState(() => _state = next);
    if (next.phase == WorkoutPhase.completed) _finish();
  }

  void _togglePause() {
    final engine = _pipeline?.engine;
    if (engine == null) return;
    engine.isPaused ? engine.resume() : engine.pause();
    _apply(engine.state);
  }

  void _skipRest() {
    final engine = _pipeline?.engine;
    if (engine == null) return;
    engine.skipRest();
    _apply(engine.state);
  }

  Future<void> _finish() async {
    if (_finished) return;
    _finished = true;
    _ticker?.cancel();
    final engine = _pipeline?.engine;
    final profile = ProfileScope.of(context);
    await _stopCamera();
    if (engine == null || !mounted) return;
    engine.finish();

    final session = WorkoutSession(
      exerciseId: widget.exercise.id,
      level: widget.level,
      correctReps: engine.correctReps,
      wrongReps: engine.wrongReps,
      completedSets: engine.completedSets,
      duration: engine.elapsed,
      calories: widget.exercise.caloriesFor(engine.elapsed, profile.weightKg ?? 70),
      createdAt: DateTime.now(),
      sets: engine.setResults,
    );

    final hasData = session.totalReps > 0;
    if (hasData) {
      // Firestore applies the write locally right away and syncs when online.
      unawaited(userRepository
          .addSession(authService.currentUser!.uid, session)
          .catchError((Object e) => debugPrint('Saving session failed: $e')));
    }
    if (!mounted) return;
    Navigator.of(context).pushReplacement(scopedRoute(context, WorkoutSummaryScreen(session: session, saved: hasData, fromWorkout: true)));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_finished || _pipeline == null) return;
    if (state == AppLifecycleState.inactive || state == AppLifecycleState.paused) {
      _pipeline!.engine.pause();
      _stopCamera();
    } else if (state == AppLifecycleState.resumed && _controller == null) {
      _startCamera();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker?.cancel();
    _stopCamera();
    _poseSource.close();
    _coach?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final s = _state;
    final countingDown = s?.phase == WorkoutPhase.countdown;

    return Scaffold(
      backgroundColor: const Color(0xFFC9CFD8),
      body: _error != null
          ? _ErrorView(message: _error!)
          : Stack(
              fit: StackFit.expand,
              children: [
                if (controller != null && controller.value.isInitialized)
                  _preview(controller)
                else
                  const Center(child: CircularProgressIndicator(color: AppColors.ink)),
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            SquareIconButton(
                              icon: Icons.close_rounded,
                              tooltip: 'Close workout',
                              background: Colors.white.withValues(alpha: 0.92),
                              bordered: false,
                              onPressed: () => Navigator.of(context).pop(),
                            ),
                            const Spacer(),
                            _TrackingPill(found: _frame != null),
                            const Spacer(),
                            SquareIconButton(
                              icon: Icons.cameraswitch_outlined,
                              tooltip: 'Switch camera',
                              background: Colors.white.withValues(alpha: 0.92),
                              bordered: false,
                              onPressed: _cameras.length > 1 ? _switchCamera : null,
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        _FeedbackPill(state: s, personVisible: _frame != null),
                        if (countingDown) Expanded(child: _Countdown(seconds: s!.secondsLeft)),
                      ],
                    ),
                  ),
                ),
                Align(
                  alignment: Alignment.bottomCenter,
                  child: _BottomSheet(
                    exercise: widget.exercise,
                    level: widget.level,
                    state: s,
                    onPause: _togglePause,
                    onFinish: _finish,
                    onSkipRest: _skipRest,
                  ),
                ),
              ],
            ),
    );
  }

  Widget _preview(CameraController controller) {
    final size = controller.value.previewSize!; // landscape (w > h)
    return FittedBox(
      fit: BoxFit.cover,
      child: SizedBox(
        width: size.height,
        height: size.width,
        child: Stack(
          fit: StackFit.expand,
          children: [
            CameraPreview(controller),
            CustomPaint(
              painter: PosePainter(
                frame: _frame,
                formOk: _state?.formOk ?? true,
                mirror: controller.description.lensDirection == CameraLensDirection.front,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TrackingPill extends StatelessWidget {
  const _TrackingPill({required this.found});
  final bool found;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.92), borderRadius: BorderRadius.circular(12)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        PulseDot(color: found ? AppColors.live : AppColors.subtle),
        const SizedBox(width: 8),
        AnimatedSwitcher(
          duration: Motion.fast,
          child: Text(
            found ? 'Tracking · 33 points' : 'Finding you…',
            key: ValueKey(found),
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          ),
        ),
      ]),
    );
  }
}

class _FeedbackPill extends StatelessWidget {
  const _FeedbackPill({required this.state, required this.personVisible});
  final WorkoutState? state;
  final bool personVisible;

  @override
  Widget build(BuildContext context) {
    final s = state;
    var (bg, fg, dot, text) = (Colors.white, AppColors.ink, AppColors.live, 'Good form — keep going');
    if (s == null || s.phase == WorkoutPhase.countdown) {
      (bg, fg, dot, text) = (Colors.white, AppColors.ink, AppColors.accent, 'Get in position');
    } else if (s.isPaused) {
      (bg, fg, dot, text) = (AppColors.ink, Colors.white, Colors.white, 'Paused');
    } else if (s.phase == WorkoutPhase.rest) {
      (bg, fg, dot, text) = (AppColors.successSoft, AppColors.successText, AppColors.success, 'Nice set! Catch your breath');
    } else if (!personVisible) {
      (bg, fg, dot, text) = (Colors.white, AppColors.ink, AppColors.subtle, 'Step back so your whole body is visible');
    } else if (!s.formOk) {
      (bg, fg, dot, text) = (AppColors.warn, Colors.white, Colors.white, s.feedback ?? 'Check your form');
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [BoxShadow(color: Color(0x1F0E1B2C), blurRadius: 14, offset: Offset(0, 4))],
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: dot, shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Flexible(
          child: AnimatedSwitcher(
            duration: Motion.fast,
            child: Text(text, key: ValueKey(text), style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: fg)),
          ),
        ),
      ]),
    );
  }
}

class _Countdown extends StatelessWidget {
  const _Countdown({required this.seconds});
  final int seconds;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 350),
          transitionBuilder: (child, a) => FadeTransition(
            opacity: a,
            child: ScaleTransition(scale: Tween(begin: 1.5, end: 1.0).animate(CurvedAnimation(parent: a, curve: Motion.curve)), child: child),
          ),
          child: Text('$seconds',
              key: ValueKey(seconds),
              style: const TextStyle(fontSize: 120, fontWeight: FontWeight.w800, height: 1, color: AppColors.ink)),
        ),
        const SizedBox(height: 8),
        const Text('Step back into the frame', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF33415A))),
        const SizedBox(height: 120),
      ],
    );
  }
}

class _BottomSheet extends StatelessWidget {
  const _BottomSheet({
    required this.exercise,
    required this.level,
    required this.state,
    required this.onPause,
    required this.onFinish,
    required this.onSkipRest,
  });

  final Exercise exercise;
  final Level level;
  final WorkoutState? state;
  final VoidCallback onPause;
  final VoidCallback onFinish;
  final VoidCallback onSkipRest;

  @override
  Widget build(BuildContext context) {
    final s = state;
    final resting = s?.phase == WorkoutPhase.rest;
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.sheet)),
        boxShadow: [BoxShadow(color: Color(0x140E1B2C), blurRadius: 24, offset: Offset(0, -8))],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 40, height: 5, decoration: BoxDecoration(color: const Color(0xFFD8DDE5), borderRadius: BorderRadius.circular(3))),
              const SizedBox(height: 16),
              AnimatedSize(
                duration: const Duration(milliseconds: 300),
                curve: Motion.curve,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: resting
                      ? _RestView(key: const ValueKey('rest'), state: s!, onSkip: onSkipRest, onFinish: onFinish)
                      : _ActiveView(key: const ValueKey('active'), exercise: exercise, level: level, state: s, onPause: onPause, onFinish: onFinish),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActiveView extends StatelessWidget {
  const _ActiveView({super.key, required this.exercise, required this.level, required this.state, required this.onPause, required this.onFinish});

  final Exercise exercise;
  final Level level;
  final WorkoutState? state;
  final VoidCallback onPause;
  final VoidCallback onFinish;

  @override
  Widget build(BuildContext context) {
    final s = state;
    final target = s?.targetReps ?? level.repsPerSet;
    final reps = s?.reps ?? 0;
    final wrong = s?.wrongReps ?? 0;
    final stage = s == null || s.phase == WorkoutPhase.countdown ? 'Ready' : (s.stage == MoveStage.up ? 'Up' : 'Down');
    final secs = s?.elapsed.inSeconds ?? 0;
    final time = '${(secs ~/ 60).toString().padLeft(2, '0')}:${(secs % 60).toString().padLeft(2, '0')}';
    final paused = s?.isPaused ?? false;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(exercise.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                Text('${level.label} · Set ${s?.currentSetNumber ?? 1} of ${s?.totalSets ?? Level.setsPerWorkout} · $stage',
                    style: const TextStyle(fontSize: 13, color: AppColors.muted)),
              ]),
            ),
            Text(time,
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF33415A), fontFeatures: [FontFeature.tabularFigures()])),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              transitionBuilder: (child, a) => ScaleTransition(
                scale: Tween(begin: 0.6, end: 1.0).animate(CurvedAnimation(parent: a, curve: Curves.easeOutBack)),
                child: FadeTransition(opacity: a, child: child),
              ),
              child: Text('$reps',
                  key: ValueKey(reps),
                  style: const TextStyle(fontSize: 64, fontWeight: FontWeight.w800, height: 0.95, letterSpacing: -2)),
            ),
            const SizedBox(width: 10),
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text('/ $target reps', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: AppColors.muted)),
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: AnimatedSwitcher(
                duration: Motion.fast,
                child: Text(
                  wrong == 0 ? 'No issues' : '$wrong to fix',
                  key: ValueKey(wrong),
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: wrong == 0 ? AppColors.success : AppColors.warn),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            for (var i = 0; i < target; i++) ...[
              if (i > 0) const SizedBox(width: 6),
              Expanded(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 350),
                  curve: Curves.easeOut,
                  height: 8,
                  decoration: BoxDecoration(
                    color: i < reps ? AppColors.accent : AppColors.border,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(child: SecondaryButton(label: paused ? 'Resume' : 'Pause', icon: paused ? Icons.play_arrow_rounded : Icons.pause_rounded, onPressed: onPause)),
            const SizedBox(width: 10),
            Expanded(flex: 2, child: PrimaryButton(label: 'Finish workout', color: AppColors.ink, onPressed: onFinish)),
          ],
        ),
      ],
    );
  }
}

class _RestView extends StatelessWidget {
  const _RestView({super.key, required this.state, required this.onSkip, required this.onFinish});
  final WorkoutState state;
  final VoidCallback onSkip;
  final VoidCallback onFinish;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeOutBack,
          builder: (_, v, child) => Transform.scale(scale: v, child: child),
          child: Container(
            width: 64,
            height: 64,
            decoration: const BoxDecoration(color: AppColors.successSoft, shape: BoxShape.circle),
            child: const Icon(Icons.check_rounded, size: 34, color: AppColors.success),
          ),
        ),
        const SizedBox(height: 12),
        Text('Set ${state.setIndex} complete!', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        Text(
          '${state.correctReps} good reps so far · next set in ${state.secondsLeft} s',
          style: const TextStyle(fontSize: 14, color: AppColors.muted),
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(child: SecondaryButton(label: 'Finish', onPressed: onFinish)),
            const SizedBox(width: 10),
            Expanded(child: PrimaryButton(label: 'Skip rest', onPressed: onSkip)),
          ],
        ),
      ],
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SoftIcon(icon: Icons.videocam_off_outlined, size: 64),
              const SizedBox(height: 16),
              Text(message, textAlign: TextAlign.center, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              const SizedBox(height: 24),
              SecondaryButton(label: 'Go back', onPressed: () => Navigator.of(context).pop()),
            ],
          ),
        ),
      );
}
