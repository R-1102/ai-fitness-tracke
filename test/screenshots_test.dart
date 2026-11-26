// Generates README screenshots and GIF frames from the real app widgets,
// filled with sample data (no Firebase, no device needed).
//
// Run with:   bash scripts/generate_screenshots.sh
// (skipped during a normal `flutter test`)

import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:fitness_tracker/core/theme.dart';
import 'package:fitness_tracker/ml/workout_engine.dart' show SetResult;
import 'package:fitness_tracker/models/exercise.dart';
import 'package:fitness_tracker/models/user_profile.dart';
import 'package:fitness_tracker/models/workout_session.dart';
import 'package:fitness_tracker/screens/auth/profile_setup_screen.dart';
import 'package:fitness_tracker/screens/auth/welcome_screen.dart';
import 'package:fitness_tracker/screens/home/home_screen.dart';
import 'package:fitness_tracker/screens/home/home_shell.dart';
import 'package:fitness_tracker/screens/profile/profile_screen.dart';
import 'package:fitness_tracker/screens/report/progress_screen.dart';
import 'package:fitness_tracker/screens/workout/exercise_detail_screen.dart';
import 'package:fitness_tracker/screens/workout/workout_summary_screen.dart';
import 'package:fitness_tracker/screens/workout/workouts_screen.dart';
import 'package:fitness_tracker/services/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart' show FontLoader;
import 'package:flutter_test/flutter_test.dart';

const _enabled = bool.fromEnvironment('SCREENSHOTS');
const _screenshotsDir = 'docs/screenshots';
const _framesDir = 'build/screenshot_frames';

/// iPhone 15-ish logical size.
const _logicalSize = Size(393, 852);

final _boundaryKey = GlobalKey();

// ---------------------------------------------------------------- sample data

const _profile = UserProfile(
  uid: 'demo',
  name: 'Sara',
  email: 'sara@example.com',
  age: 23,
  weightKg: 60,
  heightCm: 165,
  gender: Gender.female,
  level: Level.beginner,
);

List<WorkoutSession> _sampleSessions() {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  // (days ago, exercise, correct, wrong, minutes)
  const plan = [
    (0, 'squat', 22, 2, 6), (0, 'pushup', 18, 0, 5), (1, 'hammer_curl', 24, 1, 7),
    (3, 'squat', 20, 4, 6), (4, 'pushup', 16, 2, 5), (6, 'barbell_curl', 23, 1, 7),
    (8, 'squat', 18, 6, 7), (9, 'hammer_curl', 21, 3, 7), (11, 'pushup', 14, 4, 6),
    (13, 'squat', 16, 7, 7), (15, 'barbell_curl', 19, 5, 7), (18, 'pushup', 12, 5, 6),
  ];
  return [
    for (final (i, (daysAgo, id, correct, wrong, minutes)) in plan.indexed)
      WorkoutSession(
        id: 's$i',
        exerciseId: id,
        level: Level.beginner,
        correctReps: correct,
        wrongReps: wrong,
        completedSets: 3,
        duration: Duration(minutes: minutes, seconds: 12),
        calories: Exercise.byId(id).caloriesFor(Duration(minutes: minutes), 60),
        createdAt: today.subtract(Duration(days: daysAgo)).add(Duration(hours: 18, minutes: i)),
        sets: [SetResult(8, wrong ~/ 2), SetResult(8, 0), SetResult(correct - 16, wrong - wrong ~/ 2)],
      ),
  ];
}

// ---------------------------------------------------------------- helpers

Future<void> _loadFonts() async {
  final jakarta = FontLoader('PlusJakartaSans');
  for (final w in ['Regular', 'Medium', 'SemiBold', 'Bold', 'ExtraBold']) {
    final bytes = File('assets/fonts/PlusJakartaSans-$w.ttf').readAsBytesSync();
    jakarta.addFont(Future.value(ByteData.view(bytes.buffer)));
  }
  await jakarta.load();

  final flutterRoot = Platform.environment['FLUTTER_ROOT'];
  final icons = File('$flutterRoot/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf');
  if (flutterRoot != null && icons.existsSync()) {
    final loader = FontLoader('MaterialIcons')..addFont(Future.value(ByteData.view(icons.readAsBytesSync().buffer)));
    await loader.load();
  }
}

Widget _app(Widget screen, {int? tab, List<WorkoutSession>? sessions}) {
  return RepaintBoundary(
    key: _boundaryKey,
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      // Simulate a phone's safe areas (notch + home indicator).
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          padding: const EdgeInsets.only(top: 54, bottom: 34),
          viewPadding: const EdgeInsets.only(top: 54, bottom: 34),
        ),
        child: child!,
      ),
      home: ProfileScope(
        profile: _profile,
        child: SessionsScope(
          sessions: sessions ?? _sampleSessions(),
          child: tab == null
              ? screen
              : Scaffold(body: screen, bottomNavigationBar: AppNavBar(index: tab, onSelect: (_) {})),
        ),
      ),
    ),
  );
}

Future<void> _capture(WidgetTester tester, String path, {double pixelRatio = 2}) async {
  final boundary = _boundaryKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: pixelRatio);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File(path)..createSync(recursive: true);
    file.writeAsBytesSync(data!.buffer.asUint8List());
    image.dispose();
  });
}

/// Pumps [duration] in small steps so entrance animations finish.
Future<void> _settle(WidgetTester tester, [Duration duration = const Duration(seconds: 3)]) async {
  const step = Duration(milliseconds: 100);
  for (var t = Duration.zero; t < duration; t += step) {
    await tester.pump(step);
  }
}

/// Records [frames] frames at [fps] into build/screenshot_frames/<name>/.
var _frameCounters = <String, int>{};
Future<void> _record(WidgetTester tester, String name, {required Duration length, int fps = 15}) async {
  final step = Duration(milliseconds: 1000 ~/ fps);
  final count = length.inMilliseconds ~/ step.inMilliseconds;
  for (var i = 0; i < count; i++) {
    await tester.pump(step);
    final n = (_frameCounters[name] = (_frameCounters[name] ?? 0) + 1);
    await _capture(tester, '$_framesDir/$name/${n.toString().padLeft(4, '0')}.png', pixelRatio: 1);
  }
}

Future<void> _teardown(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await _settle(tester, const Duration(seconds: 2));
}

// ---------------------------------------------------------------- screens

final _screens = <String, (Widget, int?)>{
  'welcome': (const WelcomeScreen(), null),
  'setup': (const ProfileSetupScreen(profile: _profile), null),
  'home': (HomeScreen(onOpenWorkouts: () {}), 0),
  'workouts': (const WorkoutsScreen(), 1),
  'detail': (ExerciseDetailScreen(exercise: Exercise.byId('squat')), null),
  'progress': (const ProgressScreen(), 2),
  'profile': (const ProfileScreen(), 3),
};

void main() {
  setUpAll(_loadFonts);

  void sized(WidgetTester tester) {
    tester.view.physicalSize = _logicalSize * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
  }

  group('screenshots', skip: !_enabled, () {
    for (final MapEntry(key: name, value: (screen, tab)) in _screens.entries) {
      testWidgets(name, (tester) async {
        sized(tester);
        await tester.pumpWidget(_app(screen, tab: tab));
        await _settle(tester);
        await _capture(tester, '$_screenshotsDir/$name.png');
        await _teardown(tester);
      });
    }

    testWidgets('summary', (tester) async {
      sized(tester);
      final sessions = _sampleSessions();
      final latest = sessions.first;
      await tester.pumpWidget(_app(WorkoutSummaryScreen(session: latest, fromWorkout: true), sessions: sessions));
      await _settle(tester);
      await _capture(tester, '$_screenshotsDir/summary.png');
      await _teardown(tester);
    });
  });

  group('gif frames', skip: !_enabled, () {
    testWidgets('welcome animation', (tester) async {
      sized(tester);
      await tester.pumpWidget(_app(const WelcomeScreen()));
      await _record(tester, 'welcome', length: const Duration(milliseconds: 4800));
      await _teardown(tester);
    });

    testWidgets('app tour', (tester) async {
      sized(tester);
      final sessions = _sampleSessions();
      final tour = <(Widget, int?, int)>[
        (HomeScreen(onOpenWorkouts: () {}), 0, 2000),
        (const WorkoutsScreen(), 1, 1400),
        (ExerciseDetailScreen(exercise: Exercise.byId('squat')), null, 2600),
        (WorkoutSummaryScreen(session: sessions.first, fromWorkout: true), null, 2400),
        (const ProgressScreen(), 2, 2200),
      ];
      for (final (screen, tab, ms) in tour) {
        await tester.pumpWidget(_app(screen, tab: tab, sessions: sessions));
        await _record(tester, 'app-tour', length: Duration(milliseconds: ms));
        await tester.pumpWidget(const SizedBox());
        await tester.pump();
      }
      await _teardown(tester);
    });
  });
}
