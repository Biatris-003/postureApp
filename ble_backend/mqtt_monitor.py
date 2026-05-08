# """
# mqtt_monitor.py
# ───────────────
# Subscribes to ALL topics and prints everything.
# Use this to verify data is flowing correctly.

# Run on any laptop:
#     py mqtt_monitor.py
# """

# import json
# import ssl
# import paho.mqtt.client as mqtt
# from config import MQTT_BROKER_HOST, MQTT_BROKER_PORT, MQTT_USERNAME, MQTT_PASSWORD

# def on_connect(client, userdata, flags, reason_code, properties):
#     print(f"✅ Connected to HiveMQ")
#     client.subscribe("#", qos=0)   # # means ALL topics
#     print("Subscribed to all topics. Waiting for messages...\n")

# def on_message(client, userdata, msg):
#     try:
#         data = json.loads(msg.payload)
#         # Pretty print posture, compact print for raw IMU
#         if msg.topic == "posture/classification":
#             print(f"\n🧍 POSTURE → {data['posture']} (class {data['class_idx']}) at {data['timestamp']}")
#         elif msg.topic == "imu/live":
#             sensors = list(data.keys())
#             print(f"📡 LIVE snapshot — sensors present: {sensors}")
#         elif msg.topic == "imu/raw":
#           print(f"📊 RAW [{data.get('sensor_label')}] "
#                 f"Acc=({data.get('Acceleration X(g)', 0):.3f}, {data.get('Acceleration Y(g)', 0):.3f}, {data.get('Acceleration Z(g)', 0):.3f})g "
#                 f"Gyro=({data.get('Angular velocity X(°/s)', 0):.1f}, {data.get('Angular velocity Y(°/s)', 0):.1f}, {data.get('Angular velocity Z(°/s)', 0):.1f})°/s "
#                 f"Angle=({data.get('Angle X(°)', 0):.1f}, {data.get('Angle Y(°)', 0):.1f}, {data.get('Angle Z(°)', 0):.1f})° "
#                 f"Mag=({data.get('Magnetic field X(µt)', 0):.1f}, {data.get('Magnetic field Y(µt)', 0):.1f}, {data.get('Magnetic field Z(µt)', 0):.1f})µT "
#                 f"Quat=({data.get('Quaternions 0', 0):.4f}, {data.get('Quaternions 1', 0):.4f}, {data.get('Quaternions 2', 0):.4f}, {data.get('Quaternions 3', 0):.4f})")
#     except Exception as e:
#         print(f"[{msg.topic}] raw: {msg.payload[:80]}")

# client = mqtt.Client(
#     client_id="monitor",
#     callback_api_version=mqtt.CallbackAPIVersion.VERSION2,
#     protocol=mqtt.MQTTv311,
# )
# client.username_pw_set(MQTT_USERNAME, MQTT_PASSWORD)
# client.tls_set(tls_version=ssl.PROTOCOL_TLS_CLIENT)
# client.on_connect = on_connect
# client.on_message = on_message
# client.connect(MQTT_BROKER_HOST, MQTT_BROKER_PORT, keepalive=60)
# client.loop_forever()