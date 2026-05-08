# import ssl
# import time
# import paho.mqtt.client as mqtt
# from config import MQTT_BROKER_HOST, MQTT_BROKER_PORT, MQTT_USERNAME, MQTT_PASSWORD

# def on_connect(client, userdata, flags, rc):
#     if rc == 0:
#         print("✅ Connected to HiveMQ successfully!")
#         client.publish("test/hello", "it works!")
#     else:
#         print(f"❌ Failed to connect, code {rc}")

# def on_publish(client, userdata, mid):
#     print("✅ Message published! Everything is working.")
#     client.disconnect()

# client = mqtt.Client(client_id="test_client", protocol=mqtt.MQTTv311)
# client.username_pw_set(MQTT_USERNAME, MQTT_PASSWORD)
# client.tls_set(tls_version=ssl.PROTOCOL_TLS_CLIENT)
# client.on_connect = on_connect
# client.on_publish = on_publish

# print(f"Connecting to {MQTT_BROKER_HOST}:{MQTT_BROKER_PORT} ...")
# client.connect(MQTT_BROKER_HOST, MQTT_BROKER_PORT, keepalive=60)
# client.loop_forever()