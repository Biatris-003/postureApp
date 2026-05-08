MQTT_BROKER_HOST = "facfee6409bf43efb53dd01d7df4178f.s1.eu.hivemq.cloud"
MQTT_BROKER_PORT = 8883
MQTT_WS_PORT     = 8884
MQTT_USERNAME    = "posture"    # ← what you created in HiveMQ
MQTT_PASSWORD    = "Posture123"    # ← what you created in HiveMQ

TOPIC_RAW     = "imu/raw"
TOPIC_LIVE    = "imu/live"
TOPIC_POSTURE = "posture/classification"

SENSORS = {
    "f6:90:cc:01:6d:25": "t12",
    # "XX:XX:XX:XX:XX:XX": "c7",
    # "XX:XX:XX:XX:XX:XX": "t4",
    # "XX:XX:XX:XX:XX:XX": "l5",
}

WINDOW_SIZE = 200
OVERLAP     = 0.5

POSTURE_LABELS = [
    "Upright",
    "Forward Bending",
    "Backward Bending",
    "Left Bending",
    "Right Bending",
    "Unknown",
]