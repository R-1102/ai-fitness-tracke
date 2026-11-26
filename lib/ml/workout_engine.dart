import 'dart:math' as math;

import 'form_analyzers.dart';
import 'pose_classifier.dart';
import 'pose_frame.dart';
import 'rep_validator.dart';

enum WorkoutPhase { countdown, active, rest, completed }

/// Reps of one set (used for the per-set breakdown in the summary).
class SetResult {
  const SetResult(this.correct, this.wrong);
  final int correct;
  final int wrong;
}

/// Immutable snapshot of a running workout, rendered by the UI.
class WorkoutState {
  const WorkoutState({
    required this.phase,
    required this.stage,
    required this.reps,
    required this.targetReps,
    required this.setIndex,
    required this.totalSets,
    required this.correctReps,
    required this.wrongReps,
    required this.formOk,
    required this.feedback,
    required this.secondsLeft,
    required this.elapsed,
    this.isPaused = false,
    this.ignoredReps = 0,
  });

  final WorkoutPhase phase;
  final MoveStage stage;

  /// Correct reps in the current set.
  final int reps;
  final int targetReps;

  /// 0-based index of the current set.
  final int setIndex;
  final int totalSets;

  /// Totals across all sets.
  final int correctReps;
  final int wrongReps;

  final bool formOk;
  final String? feedback;

  /// Seconds left in countdown / rest (0 otherwise).
  final int secondsLeft;

  /// Time since the countdown ended (pauses excluded).
  final Duration elapsed;

  final bool isPaused;

  /// Movements that went down/up but weren't the selected exercise.
  final int ignoredReps;

  int get currentSetNumber => math.min(setIndex + 1, totalSets);

  String get message => switch (phase) {
        WorkoutPhase.countdown => 'Get ready… $secondsLeft',
        WorkoutPhase.rest => 'Set $setIndex done! Rest $secondsLeft s',
        WorkoutPhase.completed => 'Workout complete 🎉',
        WorkoutPhase.active => 'Set $currentSetNumber of $totalSets · $reps / $targetReps reps',
      };
}

/// Rep-counting state machine — a cleaned-up port of `Process_Frame()` from
/// the original Realtime*.py scripts. It contains no camera or UI code, so it
/// can be unit-tested with fake predictions.
class WorkoutEngine {
  WorkoutEngine({
    required this.targetReps,
    required MoveStage initialStage,
    this.totalSets = 3,
    this.countdown = const Duration(seconds: 5),
    this.restDuration = const Duration(seconds: 15),
    this.threshold = 0.65,
    this.validator,
    this.minRepDuration = Duration.zero,
    DateTime Function()? clock,
  })  : _stage = initialStage,
        _clock = clock ?? DateTime.now;

  final int targetReps;
  final int totalSets;
  final Duration countdown;
  final Duration restDuration;
  final double threshold;
  final DateTime Function() _clock;

  /// Confirms each rep really was the selected exercise (optional).
  final RepValidator? validator;

  /// Down->up faster than this is treated as model jitter and ignored.
  final Duration minRepDuration;

  WorkoutPhase _phase = WorkoutPhase.countdown;
  MoveStage _stage;
  MoveStage? _prevStage;
  DateTime? _startedAt;
  DateTime? _activeSince;
  DateTime? _restStartedAt;
  DateTime? _finishedAt;
  int _reps = 0;
  int _setIndex = 0;
  int _correct = 0;
  int _wrong = 0;
  int _setWrong = 0;
  int _ignored = 0;
  DateTime? _downSince;
  String? _notice;
  DateTime? _noticeUntil;
  DateTime? _pausedAt;
  final List<SetResult> _sets = [];
  FormResult _lastForm = const FormResult.correct();

  WorkoutPhase get phase => _phase;
  int get correctReps => _correct;
  int get wrongReps => _wrong;
  int get completedSets => _setIndex;
  bool get isPaused => _pausedAt != null;
  List<SetResult> get setResults => List.unmodifiable(_sets);

  /// "Now", frozen while paused.
  DateTime get _now => _pausedAt ?? _clock();

  Duration get elapsed {
    final since = _activeSince;
    if (since == null) return Duration.zero;
    return (_finishedAt ?? _now).difference(since);
  }

  /// Freezes timers and ignores predictions until [resume].
  void pause() {
    if (_pausedAt != null || _phase == WorkoutPhase.completed) return;
    _pausedAt = _clock();
  }

  void resume() {
    final pausedAt = _pausedAt;
    if (pausedAt == null) return;
    final shift = _clock().difference(pausedAt);
    DateTime? move(DateTime? t) => t?.add(shift);
    _startedAt = move(_startedAt);
    _activeSince = move(_activeSince);
    _restStartedAt = move(_restStartedAt);
    _pausedAt = null;
    _prevStage = null; // don't count a rep from a pose held during the pause
    _downSince = null;
  }

  /// Ends the rest early and starts the next set.
  void skipRest() {
    if (_phase != WorkoutPhase.rest || isPaused) return;
    _phase = WorkoutPhase.active;
    _prevStage = null;
    _downSince = null;
  }

  void start() {
    _startedAt = _clock();
    _phase = WorkoutPhase.countdown;
  }

  /// Ends the workout early (user pressed "Finish").
  void finish() {
    if (_phase == WorkoutPhase.completed) return;
    _activeSince ??= _now;
    _finishedAt = _now;
    if (_reps > 0 || _setWrong > 0) _sets.add(SetResult(_reps, _setWrong));
    _phase = WorkoutPhase.completed;
  }

  /// Advances timers (countdown / rest). Safe to call every frame or on a timer.
  WorkoutState tick() {
    if (_startedAt == null) start();
    if (isPaused) return state;
    final now = _clock();

    if (_phase == WorkoutPhase.countdown && now.difference(_startedAt!) >= countdown) {
      _phase = WorkoutPhase.active;
      _activeSince = now;
    } else if (_phase == WorkoutPhase.rest && now.difference(_restStartedAt!) >= restDuration) {
      _phase = WorkoutPhase.active;
      _prevStage = null;
    }
    return state;
  }

  /// Converts up/down probabilities to a stage. Index 0 = "up" (training label 0).
  MoveStage stageFor(List<double> upDownProbs) =>
      upDownProbs[0] > threshold ? MoveStage.up : MoveStage.down;

  /// Feeds one model prediction. Only has an effect while [phase] is active.
  WorkoutState onPrediction(List<double> upDownProbs, FormResult form) {
    tick();
    if (_phase != WorkoutPhase.active || isPaused) return state;

    _stage = stageFor(upDownProbs);
    _lastForm = form;

    final confident = upDownProbs.reduce(math.max) > threshold;
    if (confident) {
      final now = _clock();
      if (_stage == MoveStage.down && _prevStage != MoveStage.down) {
        // A new repetition starts.
        validator?.reset();
        _downSince = now;
      }
      if (_prevStage == MoveStage.down && _stage == MoveStage.up) {
        final tooFast = _downSince != null && now.difference(_downSince!) < minRepDuration;
        final check = validator?.validate() ?? const RepCheck.valid();
        if (tooFast) {
          // model flicker — ignore
        } else if (!check.counts) {
          _ignored++;
          _showNotice(check.message ?? 'That doesn\'t look like this exercise', now);
        } else if (form.isCorrect && check.isCorrect) {
          _reps++;
          _correct++;
        } else {
          _wrong++;
          _setWrong++;
          if (!check.isCorrect) _showNotice(check.message ?? 'Check your form', now);
        }
      }
      _prevStage = _stage;
    }
    // Set finishes once the target is reached and the user returns down.
    if (_reps >= targetReps && _stage == MoveStage.down) {
      _sets.add(SetResult(_reps, _setWrong));
      _setIndex++;
      _reps = 0;
      _setWrong = 0;
      if (_setIndex >= totalSets) {
        _finishedAt = _clock();
        _phase = WorkoutPhase.completed;
      } else {
        _restStartedAt = _clock();
        _phase = WorkoutPhase.rest;
      }
    }
    return state;
  }

  void _showNotice(String message, DateTime now) {
    _notice = message;
    _noticeUntil = now.add(const Duration(milliseconds: 2500));
  }

  WorkoutState get state {
    final now = _now;
    final notice = _noticeUntil != null && now.isBefore(_noticeUntil!) ? _notice : null;
    int remaining(Duration total, DateTime since) =>
        math.max(0, ((total - now.difference(since)).inMilliseconds / 1000).ceil());

    var secondsLeft = 0;
    if (_phase == WorkoutPhase.countdown && _startedAt != null) {
      secondsLeft = remaining(countdown, _startedAt!);
    } else if (_phase == WorkoutPhase.rest && _restStartedAt != null) {
      secondsLeft = remaining(restDuration, _restStartedAt!);
    }
    return WorkoutState(
      phase: _phase,
      stage: _stage,
      reps: _reps,
      targetReps: targetReps,
      setIndex: _setIndex,
      totalSets: totalSets,
      correctReps: _correct,
      wrongReps: _wrong,
      formOk: notice == null && _lastForm.isCorrect,
      feedback: notice ?? _lastForm.feedback,
      secondsLeft: secondsLeft,
      elapsed: elapsed,
      isPaused: isPaused,
      ignoredReps: _ignored,
    );
  }
}

/// Glues together: landmarks -> features -> up/down model -> form check -> engine.
class PoseWorkoutPipeline {
  PoseWorkoutPipeline({
    required this.upDownModel,
    required this.formAnalyzer,
    required this.engine,
  });

  final PoseClassifier upDownModel;
  final FormAnalyzer formAnalyzer;
  final WorkoutEngine engine;

  WorkoutState process(PoseFrame? frame) {
    if (frame == null || engine.phase != WorkoutPhase.active) return engine.tick();
    final features = extractFeatures(frame);
    final probs = upDownModel.predict(features);
    engine.validator?.observe(frame);
    final form = formAnalyzer.analyze(frame, engine.stageFor(probs), features);
    return engine.onPrediction(probs, form);
  }
}
