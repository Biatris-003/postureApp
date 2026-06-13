import 'dart:math';

/// Full port of the preprocessing pipeline from load_and_predict_realtime.py.
///
/// Sensor order and feature layout must stay consistent with training:
///   SENSORS = ["L5", "T4", "C7", "T12"]
///   Features per sensor (after select_acc_euler): acc_x, acc_y, acc_z, yaw, pitch, roll
///   Final shape per window: (200, 24)
class Preprocessing {
  // ── Constants matching Python ─────────────────────────────────────────────

  static const List<String> sensors = ['L5', 'T4', 'C7', 'T12'];

  static const List<String> accFeatures = [
    'Acceleration X(g)',
    'Acceleration Y(g)',
    'Acceleration Z(g)',
  ];
  static const List<String> gyroFeatures = [
    'Angular velocity X(°/s)',
    'Angular velocity Y(°/s)',
    'Angular velocity Z(°/s)',
  ];
  static const List<String> quatFeatures = [
    'Quaternions 0()',
    'Quaternions 1()',
    'Quaternions 2()',
    'Quaternions 3()',
  ];
  static const List<String> magAxes = ['X', 'Y', 'Z'];

  // Butter lowpass filter coefficients: butter(2, 3.0/(0.5*50), btype='low')
  // Computed with scipy.signal.butter — do NOT change.
  static const List<double> _butterB = [
    0.02785976611713602,
    0.05571953223427204,
    0.02785976611713602,
  ];
  static const List<double> _butterA = [
    1.0,
    -1.475480443592646,
    0.5869195080611902,
  ];

  // ── Public entry point ────────────────────────────────────────────────────

  /// Takes [rows] synced wide-format rows (≥ winLen + 50 recommended) and
  /// returns a (winLen, 24) array ready for TFLite inference.
  ///
  /// Exactly mirrors the Python pipeline:
  ///   preprocess_dataframe → select_acc_euler → last winLen rows
  static List<List<double>> preprocessWindow(
    List<Map<String, double>> rows,
    int winLen,
  ) {
    final full = _preprocessDataframe(rows); // (N, 60)
    final reduced = _selectAccEuler(full);   // (N, 24)
    final n = reduced.length;
    if (n <= winLen) return reduced;
    return reduced.sublist(n - winLen);      // last winLen rows → (winLen, 24)
  }

  /// Applies per-sensor normalisation (subtract mean, divide by std).
  /// [window] is (winLen, 24).  [means] and [stds] are each 4 × 6 lists
  /// loaded from loso_norm_stats.json.
  static List<List<double>> applySensorNorm(
    List<List<double>> window,
    List<List<double>> means,
    List<List<double>> stds,
  ) {
    final result = _copy2d(window);
    for (int s = 0; s < 4; s++) {
      final offset = s * 6;
      for (int t = 0; t < result.length; t++) {
        for (int f = 0; f < 6; f++) {
          result[t][offset + f] =
              (result[t][offset + f] - means[s][f]) / stds[s][f];
        }
      }
    }
    return result;
  }

  // ── preprocess_dataframe port ─────────────────────────────────────────────

  /// Mirrors preprocess_dataframe() in load_and_predict_realtime.py.
  /// Returns (N, 60) array.
  static List<List<double>> _preprocessDataframe(
      List<Map<String, double>> rows) {
    final n = rows.length;
    final blocks = <List<List<double>>>[];

    for (int si = 0; si < sensors.length; si++) {
      final sensor = sensors[si];
      // Extract raw columns ─────────────────────────────────────────────────
      final acc = _extractCols(rows, sensor, accFeatures);   // (n, 3)
      final gyr = _extractCols(rows, sensor, gyroFeatures);  // (n, 3)
      final mag = _extractMag(rows, sensor);                 // (n, 3)
      final quatRaw = _extractCols(rows, sensor, quatFeatures); // (n, 4)

      // Training used reorder_wxyz: treat sensor's q3 as w, q0 as x, q1 as y, q2 as z.
      final quats = List.generate(n, (i) {
        return _normalizeQuatReorderWxyz(
          quatRaw[i][0], quatRaw[i][1], quatRaw[i][2], quatRaw[i][3],
        );
      });

      // Remove bias (subtract column mean) ─────────────────────────────────
      _removeBiasInPlace(acc);
      _removeBiasInPlace(gyr);
      _removeBiasInPlace(mag);

      // Hampel filter (per column) ──────────────────────────────────────────
      _hampelFilterAllCols(acc);
      _hampelFilterAllCols(gyr);
      _hampelFilterAllCols(mag);

      // Butter lowpass filter (per column) ─────────────────────────────────
      _butterFilterAllCols(acc);
      _butterFilterAllCols(gyr);
      _butterFilterAllCols(mag);

      // Orientation alignment + Euler ───────────────────────────────────────
      final aVecs = <List<double>>[];
      final gVecs = <List<double>>[];
      final mVecs = <List<double>>[];
      final eVecs = <List<double>>[];

      for (int t = 0; t < n; t++) {
        aVecs.add(_rotateVec(quats[t], acc[t]));
        gVecs.add(_rotateVec(quats[t], gyr[t]));
        mVecs.add(_rotateVec(quats[t], mag[t]));
        eVecs.add(_quatToEuler(quats[t]));
      }

      // Magnitudes ──────────────────────────────────────────────────────────
      final aMag = List.generate(n, (i) => [_norm(aVecs[i])]);
      final gMag = List.generate(n, (i) => [_norm(gVecs[i])]);
      final mMag = List.generate(n, (i) => [_norm(mVecs[i])]);

      // Concatenate: [A(3), G(3), M(3), A_mag(1), G_mag(1), M_mag(1), E(3)] = 15
      final block = List.generate(n, (i) => [
            ...aVecs[i], ...gVecs[i], ...mVecs[i],
            ...aMag[i], ...gMag[i], ...mMag[i],
            ...eVecs[i],
          ]);

      blocks.add(block);
    }

    // Concatenate all 4 sensor blocks column-wise: (n, 60)
    return List.generate(n, (i) => [
          ...blocks[0][i],
          ...blocks[1][i],
          ...blocks[2][i],
          ...blocks[3][i],
        ]);
  }

  // ── select_acc_euler port ────────────────────────────────────────────────

  /// Mirrors select_acc_euler() — picks acc (0:3) and euler (12:15) per sensor.
  /// Input (N, 60) → output (N, 24).
  static List<List<double>> _selectAccEuler(List<List<double>> x) {
    return x.map((row) {
      final out = <double>[];
      for (int i = 0; i < 4; i++) {
        final start = i * 15;
        out.addAll(row.sublist(start, start + 3));       // acc
        out.addAll(row.sublist(start + 12, start + 15)); // euler
      }
      return out;
    }).toList();
  }

  // ── Quaternion helpers (exact port of Python) ─────────────────────────────

  /// Normalises a quaternion matching the training pipeline's reorder_wxyz mode.
  /// Training stored sensor q0,q1,q2,q3 and reordered to [q3, q0, q1, q2] as [w,x,y,z].
  static List<double> _normalizeQuatReorderWxyz(
      double q0, double q1, double q2, double q3) {
    var w = q3, x = q0, y = q1, z = q2; // reorder_wxyz: [q3,q0,q1,q2] → [w,x,y,z]
    final n = sqrt(w * w + x * x + y * y + z * z);
    if (n < 1e-8) return [1.0, 0.0, 0.0, 0.0];
    return [w / n, x / n, y / n, z / n];
  }

  static List<double> _quatConjugate(List<double> q) =>
      [q[0], -q[1], -q[2], -q[3]];

  static List<double> _quatMultiply(List<double> q1, List<double> q2) {
    final w1 = q1[0], x1 = q1[1], y1 = q1[2], z1 = q1[3];
    final w2 = q2[0], x2 = q2[1], y2 = q2[2], z2 = q2[3];
    return [
      w1 * w2 - x1 * x2 - y1 * y2 - z1 * z2,
      w1 * x2 + x1 * w2 + y1 * z2 - z1 * y2,
      w1 * y2 - x1 * z2 + y1 * w2 + z1 * x2,
      w1 * z2 + x1 * y2 - y1 * x2 + z1 * w2,
    ];
  }

  /// Rotate vector v by unit quaternion q: q * [0,v] * q*.
  static List<double> _rotateVec(List<double> q, List<double> v) {
    final vq = [0.0, v[0], v[1], v[2]];
    return _quatMultiply(_quatMultiply(q, vq), _quatConjugate(q)).sublist(1);
  }

  /// Returns [yaw, pitch, roll] in radians — matches quaternion_to_euler().
  static List<double> _quatToEuler(List<double> q) {
    final w = q[0], x = q[1], y = q[2], z = q[3];
    final yaw = atan2(2 * (w * z + x * y), 1 - 2 * (y * y + z * z));
    final pitchArg = (2 * (w * y - z * x)).clamp(-1.0, 1.0);
    final pitch = asin(pitchArg);
    final roll = atan2(2 * (w * x + y * z), 1 - 2 * (x * x + y * y));
    return [yaw, pitch, roll];
  }

  // ── Filters ───────────────────────────────────────────────────────────────

  /// In-place bias removal: subtract column mean.
  static void _removeBiasInPlace(List<List<double>> mat) {
    if (mat.isEmpty) return;
    final nCols = mat[0].length;
    for (int c = 0; c < nCols; c++) {
      double sum = 0;
      for (final row in mat) sum += row[c];
      final mean = sum / mat.length;
      for (final row in mat) row[c] -= mean;
    }
  }

  /// Apply hampel_filter to every column of [mat] in-place.
  static void _hampelFilterAllCols(List<List<double>> mat) {
    if (mat.isEmpty) return;
    final nCols = mat[0].length;
    for (int c = 0; c < nCols; c++) {
      final col = [for (final row in mat) row[c]];
      final filtered = _hampelFilter(col);
      for (int r = 0; r < mat.length; r++) mat[r][c] = filtered[r];
    }
  }

  /// Port of hampel_filter(x, window_size=5, n_sigmas=3).
  static List<double> _hampelFilter(List<double> x,
      {int k = 5, double nSigmas = 3.0}) {
    final n = x.length;
    final y = List<double>.from(x);
    for (int i = k; i < n - k; i++) {
      final window = x.sublist(i - k, i + k + 1);
      final median = _median(window);
      final absDev = window.map((v) => (v - median).abs()).toList();
      final mad = _median(absDev);
      if (mad < 1e-6) continue;
      if ((x[i] - median).abs() > nSigmas * 1.4826 * mad) {
        y[i] = median;
      }
    }
    return y;
  }

  /// Apply butter lowpass filtfilt to every column of [mat] in-place.
  static void _butterFilterAllCols(List<List<double>> mat) {
    if (mat.isEmpty) return;
    final nCols = mat[0].length;
    for (int c = 0; c < nCols; c++) {
      final col = [for (final row in mat) row[c]];
      final filtered = _filtfilt(_butterB, _butterA, col);
      for (int r = 0; r < mat.length; r++) mat[r][c] = filtered[r];
    }
  }

  /// Zero-phase forward-backward IIR filter (port of scipy.signal.filtfilt).
  static List<double> _filtfilt(
      List<double> b, List<double> a, List<double> x) {
    final y1 = _lfilter(b, a, x);
    final y2 = _lfilter(b, a, y1.reversed.toList());
    return y2.reversed.toList();
  }

  /// Direct-form II transposed IIR filter (2nd order, causal).
  static List<double> _lfilter(
      List<double> b, List<double> a, List<double> x) {
    final n = x.length;
    final y = List<double>.filled(n, 0.0);
    for (int i = 0; i < n; i++) {
      var val = b[0] * x[i];
      if (i >= 1) val += b[1] * x[i - 1] - a[1] * y[i - 1];
      if (i >= 2) val += b[2] * x[i - 2] - a[2] * y[i - 2];
      y[i] = val;
    }
    return y;
  }

  // ── Column extraction helpers ─────────────────────────────────────────────

  static List<List<double>> _extractCols(
      List<Map<String, double>> rows, String sensor, List<String> features) {
    return rows.map((row) {
      return features
          .map((f) => row['${sensor}_$f'] ?? 0.0)
          .toList();
    }).toList();
  }

  static List<List<double>> _extractMag(
      List<Map<String, double>> rows, String sensor) {
    return rows.map((row) => [
          row['${sensor}_Magnetic field X(uT)'] ?? 0.0,
          row['${sensor}_Magnetic field Y(uT)'] ?? 0.0,
          row['${sensor}_Magnetic field Z(uT)'] ?? 0.0,
        ]).toList();
  }

  // ── Utility ───────────────────────────────────────────────────────────────

  static double _norm(List<double> v) =>
      sqrt(v.fold(0.0, (s, x) => s + x * x));

  /// Wraps angle to (−π, π].
  static double _wrapAngle(double a) {
    while (a > pi) a -= 2 * pi;
    while (a < -pi) a += 2 * pi;
    return a;
  }

  static double _median(List<double> values) {
    final sorted = List<double>.from(values)..sort();
    final mid = sorted.length ~/ 2;
    if (sorted.length.isOdd) return sorted[mid];
    return (sorted[mid - 1] + sorted[mid]) / 2.0;
  }

  static List<List<double>> _copy2d(List<List<double>> src) =>
      src.map((row) => List<double>.from(row)).toList();
}
