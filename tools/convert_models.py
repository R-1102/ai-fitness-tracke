"""Convert the original Keras (.h5) pose models into small JSON files that the
Flutter app runs in pure Dart (see lib/ml/pose_classifier.dart).

All models share the same architecture:
    66 inputs -> Dense(128, tanh) -> Dense(64, tanh) -> Dense(32, tanh)
              -> Dense(16, tanh) -> Dense(2, softmax)

Because the networks are tiny (~19k parameters), running them directly in Dart
avoids a native TFLite dependency and keeps the app easy to build on Android
and iOS.

It also writes test fixtures (random inputs + expected outputs computed with
NumPy) so `flutter test` can verify that the Dart implementation matches.

Usage:
    pip install h5py numpy
    python tools/convert_models.py
"""

import json
import pathlib

import h5py
import numpy as np

ROOT = pathlib.Path(__file__).resolve().parent.parent
SRC = ROOT / "ml" / "models"
OUT = ROOT / "assets" / "models"
FIXTURES = ROOT / "test" / "fixtures"

MODELS = {
    "pushup_updown": "PushUp_CounterModel_UD_5Layer.h5",
    "pushup_form": "PU_RW_model55.h5",
    "squat_updown": "SQ_CounterModel_UD_5Layer.h5",
    "hammer_curl_updown": "HBC_CounterModel_UD_5Layer.h5",
    "barbell_curl_updown": "BBC_CounterModel_UD_5Layer.h5",
}


def load_dense_layers(path):
    """Return [(kernel, bias, activation), ...] in network order."""
    with h5py.File(path, "r") as f:
        config = json.loads(f.attrs["model_config"])
        layers = []
        for layer in config["config"]["layers"]:
            if layer["class_name"] != "Dense":
                continue
            name = layer["config"]["name"]
            group = f["model_weights"][name][name]
            kernel = np.array(group["kernel:0"])
            bias = np.array(group["bias:0"])
            layers.append((kernel, bias, layer["config"]["activation"]))
        return layers


def forward(layers, x):
    for kernel, bias, activation in layers:
        x = x @ kernel + bias
        if activation == "tanh":
            x = np.tanh(x)
        elif activation == "softmax":
            e = np.exp(x - x.max(axis=-1, keepdims=True))
            x = e / e.sum(axis=-1, keepdims=True)
        else:
            raise ValueError(f"Unsupported activation {activation}")
    return x


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    FIXTURES.mkdir(parents=True, exist_ok=True)
    rng = np.random.default_rng(42)

    for key, filename in MODELS.items():
        layers = load_dense_layers(SRC / filename)
        payload = {
            "name": key,
            "source": filename,
            "inputSize": int(layers[0][0].shape[0]),
            "layers": [
                {
                    "activation": act,
                    # kernel stored as [in][out], same as Keras
                    "kernel": np.round(kernel, 7).tolist(),
                    "bias": np.round(bias, 7).tolist(),
                }
                for kernel, bias, act in layers
            ],
        }
        (OUT / f"{key}.json").write_text(json.dumps(payload, separators=(",", ":")))

        # Fixtures: plausible inputs (landmark offsets relative to the nose).
        inputs = rng.uniform(-0.6, 0.6, size=(5, payload["inputSize"]))
        rounded = [(np.round(k, 7), np.round(b, 7), a) for k, b, a in layers]
        outputs = forward(rounded, inputs)
        (FIXTURES / f"{key}_fixture.json").write_text(
            json.dumps({"inputs": inputs.tolist(), "outputs": outputs.tolist()})
        )
        print(f"{key:22s} <- {filename}  layers={[l[0].shape for l in layers]}")


if __name__ == "__main__":
    main()
