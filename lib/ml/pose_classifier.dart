import 'dart:math' as math;

import 'pose_frame.dart';

/// Builds the model input exactly like the original training code:
/// for every landmark, (x - nose.x, y - nose.y)  ->  66 values.
List<double> extractFeatures(PoseFrame frame) {
  final nose = frame[Landmark.nose];
  final features = List<double>.filled(PoseFrame.landmarkCount * 2, 0);
  for (var i = 0; i < PoseFrame.landmarkCount; i++) {
    features[i * 2] = frame[i].x - nose.x;
    features[i * 2 + 1] = frame[i].y - nose.y;
  }
  return features;
}

class _DenseLayer {
  _DenseLayer(this.kernel, this.bias, this.activation);

  /// kernel[input][output], same layout as Keras.
  final List<List<double>> kernel;
  final List<double> bias;
  final String activation;

  List<double> forward(List<double> input) {
    final out = List<double>.of(bias);
    for (var i = 0; i < input.length; i++) {
      final v = input[i];
      if (v == 0) continue;
      final row = kernel[i];
      for (var j = 0; j < out.length; j++) {
        out[j] += v * row[j];
      }
    }
    switch (activation) {
      case 'tanh':
        for (var j = 0; j < out.length; j++) {
          out[j] = _tanh(out[j]);
        }
        return out;
      case 'softmax':
        final maxV = out.reduce(math.max);
        var sum = 0.0;
        for (var j = 0; j < out.length; j++) {
          out[j] = math.exp(out[j] - maxV);
          sum += out[j];
        }
        for (var j = 0; j < out.length; j++) {
          out[j] /= sum;
        }
        return out;
      case 'linear':
        return out;
      default:
        throw UnsupportedError('Activation "$activation" is not supported');
    }
  }

  static double _tanh(double x) {
    if (x > 20) return 1;
    if (x < -20) return -1;
    final e2x = math.exp(2 * x);
    return (e2x - 1) / (e2x + 1);
  }
}

/// A tiny fully-connected network (the original Keras "CNN pose" models),
/// evaluated in pure Dart. Weights come from `tools/convert_models.py`.
class PoseClassifier {
  PoseClassifier._(this.name, this.inputSize, this._layers);

  factory PoseClassifier.fromJson(Map<String, dynamic> json) {
    final layers = (json['layers'] as List).map((raw) {
      final layer = raw as Map<String, dynamic>;
      return _DenseLayer(
        (layer['kernel'] as List)
            .map((row) => (row as List).map((v) => (v as num).toDouble()).toList())
            .toList(),
        (layer['bias'] as List).map((v) => (v as num).toDouble()).toList(),
        layer['activation'] as String,
      );
    }).toList();
    return PoseClassifier._(
      json['name'] as String? ?? 'model',
      json['inputSize'] as int,
      layers,
    );
  }

  final String name;
  final int inputSize;
  final List<_DenseLayer> _layers;

  /// Returns class probabilities (softmax output).
  List<double> predict(List<double> features) {
    if (features.length != inputSize) {
      throw ArgumentError('Expected $inputSize features, got ${features.length}');
    }
    var x = features;
    for (final layer in _layers) {
      x = layer.forward(x);
    }
    return x;
  }
}
