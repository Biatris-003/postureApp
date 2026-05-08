"""
ble_reader.py
─────────────
Based on ble_realtime_receiver.py — reads BLE sensors, decodes IMU frames,
publishes to HiveMQ Cloud over TLS.

Run:
    py ble_reader.py
"""

import asyncio
import json
import ssl
from datetime import datetime
from typing import List, Optional

import numpy as np
import paho.mqtt.client as mqtt
from bleak import BleakClient, BleakScanner

from config import (
    MQTT_BROKER_HOST,
    MQTT_BROKER_PORT,
    MQTT_USERNAME,
    MQTT_PASSWORD,
    SENSORS,
    TOPIC_LIVE,
    TOPIC_RAW,
)

# ── Globals ───────────────────────────────────────────────────────────────────
PRINT_RAW        = False
PRINT_EVERY      = 1
FRAME_COUNTER    = 0
DEBUG_STATS      = False
MAG_COUNT        = 0
QUAT_COUNT       = 0
LAST_MAG         = None
LAST_QUAT        = None
REQUEST_MAG_QUAT = False
REQUEST_INTERVAL = 0.2
MAG_CMD          = bytes.fromhex("FF AA 27 3A 00")
QUAT_CMD         = bytes.fromhex("FF AA 27 51 00")

mqtt_client: mqtt.Client = None
latest: dict = {}   # latest reading per sensor label, for imu/live


# ── Frame splitting ───────────────────────────────────────────────────────────

def split_frames(payload: bytes) -> List[bytes]:
    frames, i = [], 0
    while i <= len(payload) - 20:
        if payload[i] != 0x55:
            i += 1
            continue
        frames.append(payload[i: i + 20])
        i += 20
    return frames


# ── Frame decoding ────────────────────────────────────────────────────────────

def decode_frame_0x61(frame: bytes) -> Optional[dict]:
    if len(frame) < 20 or frame[0] != 0x55 or frame[1] != 0x61:
        return None
    vals = np.frombuffer(frame[2:20], dtype="<i2")
    if vals.size < 9:
        return None
    ax, ay, az, gx, gy, gz, roll, pitch, yaw = vals[:9]
    return {
        "acc":   (ax * 16/32768,   ay * 16/32768,   az * 16/32768),
        "gyro":  (gx * 2000/32768, gy * 2000/32768, gz * 2000/32768),
        "angle": (roll * 180/32768, pitch * 180/32768, yaw * 180/32768),
    }


def decode_frame(frame: bytes) -> Optional[dict]:
    if len(frame) < 20 or frame[0] != 0x55:
        return None
    frame_type = frame[1]
    vals = np.frombuffer(frame[2:20], dtype="<i2")
    if vals.size < 3:
        return None

    if frame_type == 0x61:
        decoded = decode_frame_0x61(frame)
        if decoded:
            decoded["type"] = "0x61"
        return decoded

    if frame_type == 0x71:
        reg_l, reg_h = frame[2], frame[3]
        if reg_l == 0x3A and reg_h == 0x00:
            vals = np.frombuffer(frame[4:10], dtype="<i2")
            if vals.size < 3:
                return None
            hx, hy, hz = vals[:3]
            return {"type": "0x71_mag", "mag": (float(hx), float(hy), float(hz))}
        if reg_l == 0x51 and reg_h == 0x00:
            vals = np.frombuffer(frame[4:12], dtype="<i2")
            if vals.size < 4:
                return None
            q0, q1, q2, q3 = vals[:4]
            s = 1.0 / 32768.0
            return {"type": "0x71_quat", "quat": (q0*s, q1*s, q2*s, q3*s)}
        return None

    if frame_type == 0x54:
        mx, my, mz = vals[:3]
        s = 4912.0 / 32768.0
        return {"type": "0x54", "mag": (mx*s, my*s, mz*s)}

    if frame_type == 0x59:
        if vals.size < 4:
            return None
        q0, q1, q2, q3 = vals[:4]
        s = 1.0 / 32768.0
        return {"type": "0x59", "quat": (q0*s, q1*s, q2*s, q3*s)}

    return None


# ── Row builder — matches your CSV schema exactly ─────────────────────────────

def build_row(device_address: str, sensor_label: str, state: dict) -> dict:
    ax, ay, az   = state.get("acc",   (0.0, 0.0, 0.0))
    gx, gy, gz   = state.get("gyro",  (0.0, 0.0, 0.0))
    roll, pitch, yaw = state.get("angle", (0.0, 0.0, 0.0))
    mx, my, mz   = state.get("mag",   (0.0, 0.0, 0.0))
    q0, q1, q2, q3 = state.get("quat", (0.0, 0.0, 0.0, 1.0))
    now = datetime.now()

    return {
        # ── Matches your training CSV columns exactly ──────────────────────
        "Time":                     now.strftime("%H:%M:%S.%f")[:-3],
        "Device name":              device_address.lower(),
        "Chip Time":                now.isoformat(),
        "Acceleration X(g)":        round(ax, 6),
        "Acceleration Y(g)":        round(ay, 6),
        "Acceleration Z(g)":        round(az, 6),
        "Angular velocity X(°/s)":  round(gx, 6),
        "Angular velocity Y(°/s)":  round(gy, 6),
        "Angular velocity Z(°/s)":  round(gz, 6),
        "Angle X(°)":               round(roll,  6),
        "Angle Y(°)":               round(pitch, 6),
        "Angle Z(°)":               round(yaw,   6),
        "Magnetic field X(µt)":     round(mx, 6),
        "Magnetic field Y(µt)":     round(my, 6),
        "Magnetic field Z(µt)":     round(mz, 6),
        "Temperature(℃)":           round(state.get("temp", 0.0), 3),
        "Quaternions 0":            round(q0, 6),
        "Quaternions 1":            round(q1, 6),
        "Quaternions 2":            round(q2, 6),
        "Quaternions 3":            round(q3, 6),
        # Extra field so DL model / reconstruction knows which spine level
        "sensor_label":             sensor_label,
    }


# ── MQTT publish ──────────────────────────────────────────────────────────────

def publish_row(row: dict, sensor_label: str) -> None:
    global latest
    payload = json.dumps(row)
    mqtt_client.publish(TOPIC_RAW, payload, qos=0)
    latest[sensor_label] = row
    mqtt_client.publish(TOPIC_LIVE, json.dumps(latest), qos=0)


# ── Notification handler ──────────────────────────────────────────────────────

def notification_handler(
    sender, data: bytearray, device_address: str, sensor_label: str, state: dict
) -> None:
    global FRAME_COUNTER, MAG_COUNT, QUAT_COUNT, LAST_MAG, LAST_QUAT

    frames = split_frames(bytes(data))
    if not frames:
        return

    for frame in frames:
        FRAME_COUNTER += 1
        if PRINT_EVERY > 1 and FRAME_COUNTER % PRINT_EVERY != 0:
            continue

        if PRINT_RAW:
            print(f"[{device_address}] raw={frame.hex(' ')}")

        decoded = decode_frame(frame)
        if not decoded:
            continue

        # Update state
        if "acc"   in decoded: state["acc"]   = decoded["acc"]
        if "gyro"  in decoded: state["gyro"]  = decoded["gyro"]
        if "angle" in decoded: state["angle"] = decoded["angle"]
        if "mag"   in decoded:
            state["mag"] = decoded["mag"]
            MAG_COUNT += 1
            LAST_MAG = decoded["mag"]
        if "quat"  in decoded:
            state["quat"] = decoded["quat"]
            QUAT_COUNT += 1
            LAST_QUAT = decoded["quat"]

        # Log mag/quat frames if they arrive
        t = decoded.get("type", "")
        if t in ("0x54", "0x71_mag"):
            mx, my, mz = decoded["mag"]
            print(f"[{sensor_label}] Mag=({mx:.1f},{my:.1f},{mz:.1f})µT")
        elif t in ("0x59", "0x71_quat"):
            q0, q1, q2, q3 = decoded["quat"]
            print(f"[{sensor_label}] Quat=({q0:.4f},{q1:.4f},{q2:.4f},{q3:.4f})")

        # Publish as soon as we have acc + gyro + angle (mag+quat carried forward)
        if all(k in state for k in ("acc", "gyro", "angle")):
            row = build_row(device_address, sensor_label, state)
            publish_row(row, sensor_label)
            print(
                f"[{sensor_label}] "
                f"Acc=({state['acc'][0]:.3f},{state['acc'][1]:.3f},{state['acc'][2]:.3f})g "
                f"Angle=({state['angle'][0]:.2f},{state['angle'][1]:.2f},{state['angle'][2]:.2f})°"
            )

        if DEBUG_STATS and FRAME_COUNTER % 200 == 0:
            print(
                f"[debug] mag_frames={MAG_COUNT} quat_frames={QUAT_COUNT} "
                f"last_mag={LAST_MAG} last_quat={LAST_QUAT}"
            )


# ── BLE connect per sensor ────────────────────────────────────────────────────

async def connect_sensor(address: str, label: str) -> None:
    print(f"[{label}] Connecting to {address} …")
    while True:
        try:
            async with BleakClient(address, timeout=15.0) as client:
                if not client.is_connected:
                    raise RuntimeError("Failed to connect")

                print(f"[{label}] Connected ✓  Discovering services…")
                services = client.services

                notify_chars = [
                    ch for svc in services for ch in svc.characteristics
                    if "notify" in ch.properties
                ]
                write_chars = [
                    ch for svc in services for ch in svc.characteristics
                    if "write" in ch.properties or "write-without-response" in ch.properties
                ]
                write_char = next(
                    (c for c in write_chars if "0000ffe9" in c.uuid.lower()), None
                )

                if not notify_chars:
                    print(f"[{label}] No notify characteristics found!")
                    return

                device_state = {}

                for ch in notify_chars:
                    await client.start_notify(
                        ch.uuid,
                        lambda sender, data, addr=address, lbl=label, st=device_state: (
                            notification_handler(sender, data, addr, lbl, st)
                        ),
                    )
                    print(f"[{label}] Subscribed to {ch.uuid}")

                async def request_loop():
                    if not REQUEST_MAG_QUAT or write_char is None:
                        return
                    while True:
                        try:
                            await client.write_gatt_char(write_char.uuid, MAG_CMD,  response=False)
                            await client.write_gatt_char(write_char.uuid, QUAT_CMD, response=False)
                        except Exception:
                            pass
                        await asyncio.sleep(REQUEST_INTERVAL)

                asyncio.create_task(request_loop())

                print(f"[{label}] Streaming … (Ctrl+C to stop)")
                while client.is_connected:
                    await asyncio.sleep(1.0)

        except Exception as e:
            print(f"[{label}] Disconnected ({e}). Reconnecting in 3 s …")
            await asyncio.sleep(3.0)


# ── Main ──────────────────────────────────────────────────────────────────────

async def main() -> None:
    global mqtt_client

    # ── Connect to HiveMQ Cloud ───────────────────────────────────────────────
    mqtt_client = mqtt.Client(
        client_id="ble_reader",
        callback_api_version=mqtt.CallbackAPIVersion.VERSION2,
        protocol=mqtt.MQTTv311,
    )
    mqtt_client.username_pw_set(MQTT_USERNAME, MQTT_PASSWORD)
    mqtt_client.tls_set(tls_version=ssl.PROTOCOL_TLS_CLIENT)
    mqtt_client.connect(MQTT_BROKER_HOST, MQTT_BROKER_PORT, keepalive=60)
    mqtt_client.loop_start()
    print(f"MQTT connected → {MQTT_BROKER_HOST}:{MQTT_BROKER_PORT}")

    # ── Connect all sensors concurrently ─────────────────────────────────────
    tasks = [
        connect_sensor(address, label)
        for address, label in SENSORS.items()
    ]
    await asyncio.gather(*tasks)


if __name__ == "__main__":
    asyncio.run(main())