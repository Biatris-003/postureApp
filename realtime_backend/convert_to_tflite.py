"""
Run once from realtime_backend/ to produce:
  ../assets/models/loso_model.tflite
  ../assets/models/loso_norm_stats.json

Usage:
  python convert_to_tflite.py
"""

import json
import os
import sys

import numpy as np
import tensorflow as tf

sys.path.insert(0, os.path.dirname(__file__))
from load_and_predict_realtime import build_model, load_norms

OUT_DIR = os.path.join(os.path.dirname(__file__), "..", "assets", "models")
os.makedirs(OUT_DIR, exist_ok=True)

WIN_LEN = 200
NUM_FEATURES = 24
NUM_CLASSES = 6
WEIGHTS = os.path.join(os.path.dirname(__file__), "models", "loso_weights.weights.h5")
NORM_NPZ = os.path.join(os.path.dirname(__file__), "models", "loso_norm_stats.npz")


def convert_model():
    model = build_model((WIN_LEN, NUM_FEATURES), num_classes=NUM_CLASSES)
    model.load_weights(WEIGHTS)
    print("Loaded weights:", WEIGHTS)
    print("Model input shape:", model.input_shape)

    converter = tf.lite.TFLiteConverter.from_keras_model(model)
    # Try standard builtins first; Lambda(tf.stack / tf.reduce_sum) are
    # supported as PACK and SUM ops in TFLite builtins.
    converter.target_spec.supported_ops = [tf.lite.OpsSet.TFLITE_BUILTINS]

    try:
        tflite_model = converter.convert()
    except Exception as e:
        print(f"Builtin-only conversion failed ({e}), retrying with SELECT_TF_OPS …")
        converter.target_spec.supported_ops = [
            tf.lite.OpsSet.TFLITE_BUILTINS,
            tf.lite.OpsSet.SELECT_TF_OPS,
        ]
        tflite_model = converter.convert()

    out_path = os.path.join(OUT_DIR, "loso_model.tflite")
    with open(out_path, "wb") as f:
        f.write(tflite_model)
    print(f"TFLite model saved → {out_path}  ({len(tflite_model)/1024:.1f} KB)")

    # Quick sanity-check: run one random inference
    interp = tf.lite.Interpreter(model_content=tflite_model)
    interp.allocate_tensors()
    inp = interp.get_input_details()
    out = interp.get_output_details()
    print("TFLite input :", inp[0]["shape"], inp[0]["dtype"])
    print("TFLite output:", out[0]["shape"], out[0]["dtype"])

    dummy = np.zeros((1, WIN_LEN, NUM_FEATURES), dtype=np.float32)
    interp.set_tensor(inp[0]["index"], dummy)
    interp.invoke()
    probs = interp.get_tensor(out[0]["index"])
    print("Sanity-check probs (should sum ≈ 1):", probs, "sum =", probs.sum())


def export_norm_stats():
    means, stds = load_norms(NORM_NPZ)
    # Each mean/std is shape (1, 6) — flatten to a plain list of 6 floats.
    stats = {
        "means": [m.flatten().tolist() for m in means],
        "stds":  [s.flatten().tolist() for s in stds],
    }
    out_path = os.path.join(OUT_DIR, "loso_norm_stats.json")
    with open(out_path, "w") as f:
        json.dump(stats, f)
    print(f"Norm stats saved  → {out_path}")
    print("  means[0] (L5):", stats["means"][0])
    print("  stds[0]  (L5):", stats["stds"][0])


if __name__ == "__main__":
    convert_model()
    export_norm_stats()
    print("\nDone. Copy assets/models/ into your Flutter project if not already linked.")
