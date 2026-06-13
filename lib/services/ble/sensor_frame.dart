/// One complete sensor reading emitted by [BleReceiver] for a single device.
/// All physical units match the Python ble_realtime_receiver.py exactly.
class SensorRow {
  const SensorRow({
    required this.deviceAddress,
    required this.sensorId,
    required this.ax,
    required this.ay,
    required this.az,
    required this.gx,
    required this.gy,
    required this.gz,
    required this.angleX,
    required this.angleY,
    required this.angleZ,
    required this.mx,
    required this.my,
    required this.mz,
    required this.q0,
    required this.q1,
    required this.q2,
    required this.q3,
    required this.quatReal,
    required this.timestampUs,
  });

  /// Lowercase MAC address, e.g. "ed:35:33:d3:6c:f8"
  final String deviceAddress;

  /// Anatomical label: 'C7', 'T4', 'T12', or 'L5'
  final String sensorId;

  // Accelerometer — units: g  (scale 16/32768)
  final double ax, ay, az;

  // Gyroscope — units: deg/s  (scale 2000/32768)
  final double gx, gy, gz;

  // Euler angles — units: degrees  (scale 180/32768)
  // angleX = roll, angleY = pitch, angleZ = yaw  (matches Python build_row)
  final double angleX, angleY, angleZ;

  // Magnetometer — units: uT  (scale 4912/32768 for 0x54; raw int for 0x71_mag)
  final double mx, my, mz;

  // Quaternion from 0x71_quat reply (reg 0x51), scale 1/32768.
  // Sensor sends q0=w, q1=x, q2=y, q3=z. Preprocessing applies reorder_wxyz to match training.
  final double q0, q1, q2, q3;

  /// True once a real quaternion packet (0x59) has been received for this device.
  final bool quatReal;

  /// Wall-clock capture time in microseconds (DateTime.now().microsecondsSinceEpoch).
  final int timestampUs;

  /// Converts to the wide-format column map expected by [Preprocessing].
  /// Keys match the Python column naming exactly, e.g. "C7_Acceleration X(g)".
  Map<String, double> toWideColumns() => {
        '${sensorId}_Acceleration X(g)': ax,
        '${sensorId}_Acceleration Y(g)': ay,
        '${sensorId}_Acceleration Z(g)': az,
        '${sensorId}_Angular velocity X(°/s)': gx,
        '${sensorId}_Angular velocity Y(°/s)': gy,
        '${sensorId}_Angular velocity Z(°/s)': gz,
        '${sensorId}_Angle X(°)': angleX,
        '${sensorId}_Angle Y(°)': angleY,
        '${sensorId}_Angle Z(°)': angleZ,
        '${sensorId}_Magnetic field X(uT)': mx,
        '${sensorId}_Magnetic field Y(uT)': my,
        '${sensorId}_Magnetic field Z(uT)': mz,
        '${sensorId}_Quaternions 0()': q0,
        '${sensorId}_Quaternions 1()': q1,
        '${sensorId}_Quaternions 2()': q2,
        '${sensorId}_Quaternions 3()': q3,
      };
}

/// Per-device accumulation state inside [BleReceiver].
class DeviceState {
  double ax = 0, ay = 0, az = 0;
  double gx = 0, gy = 0, gz = 0;
  double angleX = 0, angleY = 0, angleZ = 0;
  double mx = 0, my = 0, mz = 0;
  double q0 = 1, q1 = 0, q2 = 0, q3 = 0; // identity quat: w=q0=1 for no_reorder mode
  bool quatReal = false;
  bool hasAcc = false;
}
