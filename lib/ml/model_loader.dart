import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../models/exercise.dart';
import 'form_analyzers.dart';
import 'pose_classifier.dart';
import 'workout_engine.dart';

/// Loads model weights from assets (cached) and builds a ready-to-use pipeline.
class ModelLoader {
  ModelLoader._();
  static final instance = ModelLoader._();

  final _cache = <String, PoseClassifier>{};

  Future<PoseClassifier> load(String asset) async {
    final cached = _cache[asset];
    if (cached != null) return cached;
    final raw = await rootBundle.loadString(asset);
    final model = PoseClassifier.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    return _cache[asset] = model;
  }

  Future<PoseWorkoutPipeline> pipelineFor(Exercise exercise, Level level) async {
    final upDown = await load(exercise.upDownModelAsset);
    final FormAnalyzer analyzer = switch (exercise.formCheck) {
      FormCheck.bicepAngle => const BicepCurlFormAnalyzer(),
      FormCheck.squatKnees => const SquatFormAnalyzer(),
      FormCheck.pushupModel => ModelFormAnalyzer(
          await load(exercise.formModelAsset!),
          feedback: 'Keep your body in a straight line',
        ),
    };
    return PoseWorkoutPipeline(
      upDownModel: upDown,
      formAnalyzer: analyzer,
      engine: WorkoutEngine(
        targetReps: level.repsPerSet,
        totalSets: Level.setsPerWorkout,
        initialStage: exercise.initialStage,
      ),
    );
  }
}
