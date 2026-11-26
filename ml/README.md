# ML — pose classification models

This folder contains the original models and training code from the graduation
project (Python, MediaPipe + Keras, trained in Google Colab).

```
ml/
├── models/      original Keras .h5 files (source of truth)
└── training/    Colab notebooks exported as .py (data → landmarks → model)
```

## How the models work

1. **Landmarks** – MediaPipe Pose extracts 33 body landmarks from each image.
2. **Features** – every landmark is made relative to the nose:
   `(x_i − x_nose, y_i − y_nose)` → 66 numbers.
3. **Network** – a small fully-connected network:
   `66 → 128 → 64 → 32 → 16 → 2` (tanh, softmax), RMSprop, early stopping.

| Model file                         | Purpose                         | Output index 0 / 1 |
|-----------------------------------|----------------------------------|--------------------|
| `PushUp_CounterModel_UD_5Layer.h5` | push-up stage                    | up / down          |
| `PU_RW_model55.h5`                 | push-up form                     | wrong / right      |
| `SQ_CounterModel_UD_5Layer.h5`     | squat stage                      | up / down          |
| `HBC_CounterModel_UD_5Layer.h5`    | hammer curl stage                | up / down          |
| `BBC_CounterModel_UD_5Layer.h5`    | barbell curl stage               | up / down          |

Rule-based checks complete the form analysis:
* **Bicep curls** – angle between the upper arm and the vertical; ≥ 12° means the elbow is drifting.
* **Squats** – knee-width / foot-width ratio; too small means the knees cave in.

Dataset: 389 curated images across the four exercises (80/20 split).
Reported results for the final approach: precision 93%, recall 88%, F1 94%.

## Using the models in the Flutter app

The networks are tiny, so the app runs them in pure Dart instead of TFLite.
Convert after retraining:

```bash
pip install h5py numpy
python tools/convert_models.py     # writes assets/models/*.json + test fixtures
flutter test                       # checks Dart output == NumPy output
```

ML Kit's pose detector (used by the app) is based on the same BlazePose model
and returns the same 33 landmarks in the same order as MediaPipe, so the
trained models are reused without retraining.

## Ideas to improve
- Collect more data (only 389 images) — especially phone-camera angles.
- Train on sequences (e.g. 1D-CNN/GRU over landmark windows) instead of single frames.
- Add right/wrong form models for squats and curls.
- Normalise features by torso size so distance from the camera matters less.
