import 'package:fitness_tracker/ml/form_analyzers.dart';
import 'package:fitness_tracker/ml/pose_frame.dart';
import 'package:fitness_tracker/ml/workout_engine.dart';
import 'package:flutter_test/flutter_test.dart';

const up = [0.9, 0.1];
const down = [0.1, 0.9];
const unsure = [0.55, 0.45];
const good = FormResult.correct();
const bad = FormResult.wrong('fix it');

void main() {
  late DateTime now;
  late WorkoutEngine engine;

  void advance(int seconds) => now = now.add(Duration(seconds: seconds));

  void rep({FormResult form = good}) {
    engine.onPrediction(down, form);
    engine.onPrediction(up, form);
  }

  setUp(() {
    now = DateTime(2025);
    engine = WorkoutEngine(
      targetReps: 3,
      totalSets: 2,
      initialStage: MoveStage.down,
      clock: () => now,
    )..start();
  });

  test('ignores predictions during the countdown', () {
    rep();
    expect(engine.state.phase, WorkoutPhase.countdown);
    expect(engine.correctReps, 0);
    advance(5);
    expect(engine.tick().phase, WorkoutPhase.active);
  });

  test('counts a rep on a confident down -> up transition', () {
    advance(5);
    rep();
    rep();
    expect(engine.state.reps, 2);
    expect(engine.correctReps, 2);
  });

  test('low-confidence frames do not count reps', () {
    advance(5);
    engine.onPrediction(down, good);
    engine.onPrediction(unsure, good);
    expect(engine.correctReps, 0);
  });

  test('bad form counts as a wrong rep', () {
    advance(5);
    rep(form: bad);
    expect(engine.wrongReps, 1);
    expect(engine.correctReps, 0);
    expect(engine.state.feedback, 'fix it');
  });

  test('rest between sets, then completes', () {
    advance(5);
    for (var i = 0; i < 3; i++) {
      rep();
    }
    engine.onPrediction(down, good); // back down => set complete
    expect(engine.state.phase, WorkoutPhase.rest);
    expect(engine.state.secondsLeft, 15);

    rep(); // ignored while resting
    expect(engine.correctReps, 3);

    advance(15);
    expect(engine.tick().phase, WorkoutPhase.active);
    for (var i = 0; i < 3; i++) {
      rep();
    }
    engine.onPrediction(down, good);
    expect(engine.state.phase, WorkoutPhase.completed);
    expect(engine.correctReps, 6);
    expect(engine.completedSets, 2);
  });

  test('finish() stops the workout early', () {
    advance(5);
    rep();
    advance(30);
    engine.finish();
    expect(engine.state.phase, WorkoutPhase.completed);
    expect(engine.elapsed, const Duration(seconds: 30));
  });

  test('pause freezes the clock and ignores reps', () {
    advance(5);
    rep();
    advance(10);
    engine.pause();
    rep(); // ignored
    advance(60); // paused time must not count
    expect(engine.state.isPaused, isTrue);
    expect(engine.elapsed, const Duration(seconds: 10));
    engine.resume();
    advance(5);
    expect(engine.correctReps, 1);
    expect(engine.elapsed, const Duration(seconds: 15));
  });

  test('pause during rest keeps the remaining rest time', () {
    advance(5);
    for (var i = 0; i < 3; i++) {
      rep();
    }
    engine.onPrediction(down, good);
    advance(5);
    engine.pause();
    advance(100);
    engine.resume();
    expect(engine.tick().phase, WorkoutPhase.rest);
    expect(engine.state.secondsLeft, 10);
  });

  test('skipRest starts the next set immediately', () {
    advance(5);
    for (var i = 0; i < 3; i++) {
      rep();
    }
    engine.onPrediction(down, good);
    expect(engine.state.phase, WorkoutPhase.rest);
    engine.skipRest();
    expect(engine.state.phase, WorkoutPhase.active);
  });

  test('records per-set results, including a partial last set', () {
    advance(5);
    rep(form: bad);
    for (var i = 0; i < 3; i++) {
      rep();
    }
    engine.onPrediction(down, good);
    engine.skipRest();
    rep();
    engine.finish();
    final sets = engine.setResults;
    expect(sets.length, 2);
    expect((sets[0].correct, sets[0].wrong), (3, 1));
    expect((sets[1].correct, sets[1].wrong), (1, 0));
  });

  group('form analyzers', () {
    List<PosePoint> standing() => List.generate(33, (_) => const PosePoint(0.5, 0.5));

    test('bicep: elbow under shoulder is correct, drifted elbow is wrong', () {
      final pts = standing();
      pts[Landmark.rightShoulder] = const PosePoint(0.5, 0.3);
      pts[Landmark.rightElbow] = const PosePoint(0.5, 0.5);
      pts[Landmark.leftShoulder] = const PosePoint(0.5, 0.3, 0.1);
      pts[Landmark.leftElbow] = const PosePoint(0.5, 0.5, 0.1);
      const analyzer = BicepCurlFormAnalyzer();
      expect(analyzer.analyze(PoseFrame(pts), MoveStage.up, const []).isCorrect, isTrue);

      pts[Landmark.rightElbow] = const PosePoint(0.62, 0.5); // ~31° forward
      expect(analyzer.analyze(PoseFrame(pts), MoveStage.up, const []).isCorrect, isFalse);
    });

    test('squat: knees narrower than feet is wrong', () {
      final pts = standing();
      pts[Landmark.leftFootIndex] = const PosePoint(0.3, 0.9);
      pts[Landmark.rightFootIndex] = const PosePoint(0.7, 0.9);
      pts[Landmark.leftKnee] = const PosePoint(0.32, 0.7);
      pts[Landmark.rightKnee] = const PosePoint(0.68, 0.7);
      const analyzer = SquatFormAnalyzer();
      expect(analyzer.analyze(PoseFrame(pts), MoveStage.down, const []).isCorrect, isTrue);

      pts[Landmark.leftKnee] = const PosePoint(0.45, 0.7);
      pts[Landmark.rightKnee] = const PosePoint(0.55, 0.7);
      expect(analyzer.analyze(PoseFrame(pts), MoveStage.down, const []).isCorrect, isFalse);
    });
  });
}
