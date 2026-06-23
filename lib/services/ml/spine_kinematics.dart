import 'dart:math';

/// A single vertebral position in 3D space.
///
/// Origin is the sacrum. Y is up, X is forward (anterior), Z is right (lateral).
/// All values are normalized: the full sacrum-to-C1 height equals 1.0.
class SpinePoint3D {
  const SpinePoint3D(this.x, this.y, this.z);

  final double x; // forward / backward
  final double y; // up
  final double z; // left / right
}

/// Computes a 25-point 3D vertebral chain from 4 IMU sensor quaternions.
///
/// Sensor order matches the LOSO model: L5, T4, C7, T12.
/// All sensors also present here as named map keys.
class SpineKinematics {
  // Conservative seated human-motion limits. These cap noisy IMU values before
  // they are converted into the visible vertebral chain.
  static const double _maxSagittalDeflection = 40 * pi / 180;
  static const double _maxLateralDeflection = 20 * pi / 180;
  static const double _maxVisibleSagittalAngle = 45 * pi / 180;
  static const double _maxVisibleLateralAngle = 22 * pi / 180;

  // ── Vertebral anatomy ────────────────────────────────────────────────────

  /// Names from sacrum (index 0) to C1 (index 24).
  static const List<String> levelNames = [
    'S1',
    'L5',
    'L4',
    'L3',
    'L2',
    'L1',
    'T12',
    'T11',
    'T10',
    'T9',
    'T8',
    'T7',
    'T6',
    'T5',
    'T4',
    'T3',
    'T2',
    'T1',
    'C7',
    'C6',
    'C5',
    'C4',
    'C3',
    'C2',
    'C1',
  ];

  // Sensor vertebra indices in the chain.
  static const int idxL5 = 1;
  static const int idxT12 = 6;
  static const int idxT4 = 14;
  static const int idxC7 = 18;
  static const int numLevels = 25;

  // Approximate inter-vertebral segment lengths (mm), normalized to sum = 1.
  // S1→L5: 35mm  |  L5→T12: 5×25mm  |  T12→T4: 8×22mm
  // T4→C7: 4×22mm  |  C7→C1: 6×15mm
  static final List<double> segLengths = _buildSegLengths();

  static List<double> _buildSegLengths() {
    final raw = [
      35.0, // S1 → L5
      25.0, 25.0, 25.0, 25.0, 25.0, // L5 → T12
      22.0, 22.0, 22.0, 22.0,
      22.0, 22.0, 22.0, 22.0, // T12 → T4
      22.0, 22.0, 22.0, 22.0, // T4  → C7
      15.0, 15.0, 15.0, 15.0, 15.0, 15.0, // C7 → C1
    ];
    final total = raw.fold(0.0, (a, b) => a + b);
    return raw.map((v) => v / total).toList();
  }

  // ── Neutral-pose baselines from LOSO norm stats ──────────────────────────

  // Training-mean pitch (rad) per sensor — represents neutral sitting posture.
  static const Map<String, double> _neutralPitch = {
    'L5': 1.207,
    'T12': 1.221,
    'T4': 0.848,
    'C7': 0.701,
  };

  // Anatomical S-curve: per-vertebra pitch offset (rad) baked into the neutral
  // pose so the spine renders with natural lordosis/kyphosis at zero deflection.
  // Positive = anterior (lordosis), negative = posterior (kyphosis).
  // Index 0 = S1, 24 = C1.
  static final List<double> _baselinePitch = () {
    const d = pi / 180;
    return [
      0 * d, // S1
      6 * d, // L5  ─┐
      8 * d, // L4   │ lumbar lordosis (~30° total)
      9 * d, // L3   │
      8 * d, // L2   │
      5 * d, // L1  ─┘
      2 * d, // T12
      -3 * d, // T11 ─┐
      -5 * d, // T10  │
      -6 * d, // T9   │ thoracic kyphosis (~35° total)
      -7 * d, // T8   │
      -7 * d, // T7   │
      -6 * d, // T6   │
      -5 * d, // T5   │
      -4 * d, // T4  ─┘
      -3 * d, // T3
      -2 * d, // T2
      -1 * d, // T1
      2 * d, // C7  ─┐
      4 * d, // C6   │ cervical lordosis (~22° total)
      5 * d, // C5   │
      5 * d, // C4   │
      4 * d, // C3   │
      3 * d, // C2   │
      3 * d, // C1  ─┘
    ];
  }();

  // ── Quaternion math ──────────────────────────────────────────────────────

  /// Wraps an angle to the range (-π, π].
  static double _wrapAngle(double a) {
    var v = a % (2 * pi);
    if (v > pi) v -= 2 * pi;
    return v;
  }

  /// Reorders sensor [q0,q1,q2,q3] → [w=q3, x=q0, y=q1, z=q2] and normalizes.
  static List<double> _reorderWxyz(List<double> q) {
    final w = q[3], x = q[0], y = q[1], z = q[2];
    final n = sqrt(w * w + x * x + y * y + z * z);
    if (n < 1e-8) return [1.0, 0.0, 0.0, 0.0];
    return [w / n, x / n, y / n, z / n];
  }

  /// Returns q_neutral⁻¹ * q_current — the rotation FROM neutral TO current.
  ///
  /// Both inputs are raw sensor format [q0,q1,q2,q3].
  /// Output is [w,x,y,z] (already reordered & normalized).
  ///
  /// Extracting Euler angles from this relative quaternion gives true
  /// sagittal/lateral deflections with no cross-axis coupling: a pure
  /// forward bend produces only pitch, not a spurious roll.
  static List<double> _relativeQuat(
    List<double> qNeutral,
    List<double> qCurrent,
  ) {
    final qn = _reorderWxyz(qNeutral);
    final qc = _reorderWxyz(qCurrent);
    // Inverse of a unit quaternion = its conjugate: [w, -x, -y, -z]
    final nw = qn[0], nx = -qn[1], ny = -qn[2], nz = -qn[3];
    final cw = qc[0], cx = qc[1], cy = qc[2], cz = qc[3];
    return [
      nw * cw - nx * cx - ny * cy - nz * cz,
      nw * cx + nx * cw + ny * cz - nz * cy,
      nw * cy - nx * cz + ny * cw + nz * cx,
      nw * cz + nx * cy - ny * cx + nz * cw,
    ];
  }

  /// Returns pitch in radians (ZYX decomposition, rotation around Y axis).
  /// With X=superior, Y=right, Z=posterior sensor orientation, this captures
  /// sagittal flexion/extension. Sign is inverted relative to convention
  /// (forward bend → negative pitch), corrected by negating at call sites.
  static double _quatPitch(List<double> q) {
    final w = q[0], x = q[1], y = q[2], z = q[3];
    return asin((2 * (w * y - z * x)).clamp(-1.0, 1.0));
  }

  /// Returns yaw in radians (ZYX decomposition, rotation around Z axis).
  /// With X=superior, Y=right, Z=posterior, yaw captures lateral bending
  /// (rotation around the posterior axis). Roll (around X=superior) captures
  /// axial twist instead, so we use yaw for the coronal visualization.
  static double _quatYaw(List<double> q) {
    final w = q[0], x = q[1], y = q[2], z = q[3];
    return atan2(2 * (w * z + x * y), 1 - 2 * (y * y + z * z));
  }

  // ── Public API ───────────────────────────────────────────────────────────

  /// Computes 25 vertebral positions in 3D from 4 sensor quaternion maps.
  ///
  /// [sensorQuats] maps sensorId → [q0, q1, q2, q3] (raw sensor ordering).
  /// [neutralQuats] is the calibration snapshot (upright sitting). When
  /// provided, deflections are computed relative to it; otherwise falls back
  /// to hardcoded training means.
  ///
  /// Returns positions from sacrum (index 0) to C1 (index 24).
  /// All positions are normalized so the total chain height ≈ 1.0.
  static List<SpinePoint3D> compute(
    Map<String, List<double>> sensorQuats, {
    Map<String, List<double>>? neutralQuats,
  }) {
    // Step 1: pitch/roll deflection from neutral per sensor.
    // When neutralQuats are available (calibrated), use the relative quaternion
    // q_neutral⁻¹ * q_current so axes decouple: sagittal bend → pure pitch,
    // lateral bend → pure roll, no cross-axis leakage.
    // Sagittal deflection: negated because Z=posterior inverts the pitch sign.
    // Forward bending → sensor X+(superior) tilts toward -Z(anterior)
    // → negative ZYX pitch → negate to get positive for forward in the chain.
    double deflPitch(String id) {
      final q = sensorQuats[id];
      if (q == null) return 0.0;
      final nq = neutralQuats?[id];
      final value = nq != null
          ? -_quatPitch(_relativeQuat(nq, q))
          : -(_quatPitch(_reorderWxyz(q)) - (_neutralPitch[id] ?? 0.0));
      return value
          .clamp(-_maxSagittalDeflection, _maxSagittalDeflection)
          .toDouble();
    }

    // Lateral deflection: uses yaw (rotation around Z=posterior) because with
    // X=superior and Z=posterior, lateral bending is rotation around Z, which
    // maps to yaw in ZYX decomp — not roll (which captures axial twist).
    double deflRoll(String id) {
      final q = sensorQuats[id];
      if (q == null) return 0.0;
      final nq = neutralQuats?[id];
      final value = nq != null
          ? _quatYaw(_relativeQuat(nq, q))
          : _wrapAngle(_quatYaw(_reorderWxyz(q)));
      return value
          .clamp(-_maxLateralDeflection, _maxLateralDeflection)
          .toDouble();
    }

    // final dpL5 = deflPitch('L5');
    // final drL5 = deflRoll('L5');
    // final dpT12 = deflPitch('T12');
    // final drT12 = deflRoll('T12');
    // final dpT4 = deflPitch('T4');
    // final drT4 = deflRoll('T4');
    // final dpC7 = deflPitch('C7');
    // final drC7 = deflRoll('C7');

    final dpL5 = -deflRoll('L5');
    final drL5 = deflPitch('L5');

    final dpT12 = -deflRoll('T12');
    final drT12 = deflPitch('T12');

    final dpT4 = -deflRoll('T4');
    final drT4 = deflPitch('T4');

    final dpC7 = -deflRoll('C7');
    final drC7 = deflPitch('C7');
    
    // Step 2: smooth interpolation of deflections at each vertebral level.
    final pitch = List<double>.filled(numLevels, 0.0);
    final roll = List<double>.filled(numLevels, 0.0);

    void lerp(int from, int to, double p0, double p1, double r0, double r1) {
      for (int i = from; i <= to; i++) {
        final rawT = (i - from) / (to - from);
        final t = rawT * rawT * (3 - 2 * rawT);
        pitch[i] = p0 + (p1 - p0) * t;
        roll[i] = r0 + (r1 - r0) * t;
      }
    }

    // Sacrum (index 0) extrapolated from L5.
    pitch[0] = dpL5;
    roll[0] = drL5;

    lerp(idxL5, idxT12, dpL5, dpT12, drL5, drT12);
    lerp(idxT12, idxT4, dpT12, dpT4, drT12, drT4);
    lerp(idxT4, idxC7, dpT4, dpC7, drT4, drC7);

    // C7 → C1: extrapolate from C7.
    for (int i = idxC7; i < numLevels; i++) {
      pitch[i] = dpC7;
      roll[i] = drC7;
    }

    // Step 3: integrate forward-kinematic chain from sacrum upward.
    // direction = (sin(p)*cos(r), cos(p)*cos(r), sin(r)) where p,r are deflections.
    // When p=r=0 the spine points straight up (0,1,0) = neutral.
    final positions = <SpinePoint3D>[];
    double px = 0, py = 0, pz = 0;
    positions.add(const SpinePoint3D(0, 0, 0)); // sacrum at origin

    for (int i = 0; i < numLevels - 1; i++) {
      final p = (_baselinePitch[i] + pitch[i])
          .clamp(-_maxVisibleSagittalAngle, _maxVisibleSagittalAngle)
          .toDouble();
      final r = roll[i]
          .clamp(-_maxVisibleLateralAngle, _maxVisibleLateralAngle)
          .toDouble();
      final l = segLengths[i];
      px += l * sin(p) * cos(r);
      py += l * cos(p) * cos(r);
      pz += l * sin(r);
      positions.add(SpinePoint3D(px, py, pz));
    }

    return positions;
  }

  /// Returns clinical curvature angles in degrees.
  ///
  /// Keys: 'lumbarLordosis', 'thoracicKyphosis', 'cervicalLordosis', 'lateralDeviation'.
  /// [neutralQuats] is the calibration snapshot — required for a meaningful
  /// lateralDeviation reading.
  static Map<String, double> clinicalAngles(
    Map<String, List<double>> sensorQuats, {
    Map<String, List<double>>? neutralQuats,
  }) {
    double pitch(String id) {
      final q = sensorQuats[id];
      return q == null ? 0.0 : _quatPitch(_reorderWxyz(q));
    }

    double rollDefl(String id) {
      final q = sensorQuats[id];
      if (q == null) return 0.0;
      final nq = neutralQuats?[id];
      if (nq != null) return _quatYaw(_relativeQuat(nq, q));
      return _wrapAngle(_quatYaw(_reorderWxyz(q)));
    }

    final pL5 = pitch('L5');
    final pT12 = pitch('T12');
    final pT4 = pitch('T4');
    final pC7 = pitch('C7');

    const toDeg = 180 / pi;
    return {
      'lumbarLordosis': (pL5 - pT12).abs() * toDeg,
      'thoracicKyphosis': (pT12 - pT4).abs() * toDeg,
      'cervicalLordosis': (pT4 - pC7).abs() * toDeg,
      'lateralDeviation': [
        rollDefl('L5'),
        rollDefl('T12'),
        rollDefl('T4'),
        rollDefl('C7'),
      ].map((r) => r.abs() * toDeg).reduce((a, b) => a > b ? a : b),
    };
  }
}
