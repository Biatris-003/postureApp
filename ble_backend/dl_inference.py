"""
dl_inference.py
───────────────
Subscribes to imu/raw on HiveMQ Cloud, maintains a 200-frame sliding
window per sensor, runs the DL model every 100 frames (50% overlap),
and publishes the posture classification to posture/classification.

Run on any laptop (no BLE needed, just internet + your model file):
    py dl_inference.py --model path/to/your_model.h5
"""

import argparse
import json
import logging
import ssl
from collections import deque

import numpy as np
import paho.mqtt.client as mqtt

from config import (
    MQTT_BROKER_HOST,
    MQTT_BROKER_PORT,
    MQTT_USERNAME,
    MQTT_PASSWORD,
    POSTURE_LABELS,
    SENSORS,
    TOPIC_POSTURE,
    TOPIC_RAW,
    WINDOW_SIZE,
    OVERLAP,
)

logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] %(message)s")
log = logging.getLogger(__name__)

# Must match the column order your model was trained on
FEATURE_COLS = [
    "Acceleration X(g)",
    "Acceleration Y(g)",
    "Acceleration Z(g)",
    "Angular velocity X(°/s)",
    "Angular velocity Y(°/s)",
    "Angular velocity Z(°/s)",
    "Angle X(°)",
    "Angle Y(°)",
    "Angle Z(°)",
    "Magnetic field X(µt)",
    "Magnetic field Y(µt)",
    "Magnetic field Z(µt)",
    "Quaternions 0",
    "Quaternions 1",
    "Quaternions 2",
    "Quaternions 3",
]

SENSOR_LABELS = list(SENSORS.values())
STEP = int(WINDOW_SIZE * (1 - OVERLAP))   # 100 frames between inferences

engine = None
mqtt_client = None


class InferenceEngine:
    def __init__(self, model_path: str):
        import tensorflow as tf
        self.model = tf.keras.models.load_model(model_path)
        self.buffers = {label: deque(maxlen=WINDOW_SIZE) for label in SENSOR_LABELS}
        self.counts  = {label: 0 for label in SENSOR_LABELS}
        log.info(f"Model loaded: {model_path}")

    def feed(self, row: dict):
        label = row.get("sensor_label")
        if label not in self.buffers:
            return None
        features = [float(row.get(col, 0.0)) for col in FEATURE_COLS]
        self.buffers[label].append(features)
        self.counts[label] += 1
        if (
            len(self.buffers[label]) == WINDOW_SIZE
            and self.counts[label] % STEP == 0
        ):
            return self._infer()
        return None

    def _infer(self):
        # Wait until all sensors have a full window
        if any(len(self.buffers[l]) < WINDOW_SIZE for l in SENSOR_LABELS):
            log.debug("Not all sensors ready yet, skipping inference.")
            return None
        arrays = [np.array(list(self.buffers[l])) for l in SENSOR_LABELS]
        x = np.concatenate(arrays, axis=1)[np.newaxis, ...]
        try:
            preds = self.model.predict(x, verbose=0)
            idx = int(np.argmax(preds[0]))
            label_str = POSTURE_LABELS[idx] if idx < len(POSTURE_LABELS) else "Unknown"
            return label_str, idx
        except Exception as e:
            log.error(f"Inference error: {e}")
            return None


def on_message(client, userdata, msg):
    try:
        row = json.loads(msg.payload)
    except json.JSONDecodeError:
        return
    result = engine.feed(row)
    if result:
        label_str, class_idx = result
        out = json.dumps({
            "posture":   label_str,
            "class_idx": class_idx,
            "timestamp": row.get("Time", ""),
        })
        client.publish(TOPIC_POSTURE, out, qos=0)
        log.info(f"Posture → {label_str} (class {class_idx})")


def main():
    global engine, mqtt_client

    parser = argparse.ArgumentParser()
    parser.add_argument("--model", required=True, help="Path to trained model (.h5)")
    args = parser.parse_args()

    engine = InferenceEngine(args.model)

    mqtt_client = mqtt.Client(
        client_id="dl_inference",
        callback_api_version=mqtt.CallbackAPIVersion.VERSION2,
        protocol=mqtt.MQTTv311,
    )
    mqtt_client.username_pw_set(MQTT_USERNAME, MQTT_PASSWORD)
    mqtt_client.tls_set(tls_version=ssl.PROTOCOL_TLS_CLIENT)
    mqtt_client.on_message = on_message
    mqtt_client.connect(MQTT_BROKER_HOST, MQTT_BROKER_PORT, keepalive=60)
    mqtt_client.subscribe(TOPIC_RAW, qos=0)

    log.info(f"Connected → {MQTT_BROKER_HOST}. Waiting for sensor data …")
    mqtt_client.loop_forever()


if __name__ == "__main__":
    main()