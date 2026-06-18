import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../services/ml/spine_kinematics.dart';
import '../../../services/session_provider.dart';

// ── SpineViewTab ─────────────────────────────────────────────────────────────

class SpineViewTab extends ConsumerStatefulWidget {
  const SpineViewTab({super.key});

  @override
  ConsumerState<SpineViewTab> createState() => _SpineViewTabState();
}

class _SpineViewTabState extends ConsumerState<SpineViewTab>
    with SingleTickerProviderStateMixin {
  late final AnimationController _breathe;
  late final WebViewController _wvc;
  bool _webReady = false;

  // Neutral quaternions captured at calibration time (upright sitting).
  // Auto-set on first data frame; user can reset via the Calibrate button.
  Map<String, List<double>>? _neutralQuats;
  bool _autoCalibrated = false;

  // ── Adaptive drift correction ────────────────────────────────────────────
  // When all sensors are approximately still (|q_prev · q_curr| > threshold),
  // the neutral is slowly SLERP-ed towards the current reading so IMU gyro
  // drift doesn't accumulate visible error over time.
  static const _stillDot  = 0.9995; // ≈ 3.2° between frames = "still"
  static const _driftRate = 0.005;  // 0.5 % correction per 200 ms frame

  static double _dot(List<double> a, List<double> b) =>
      a[0]*b[0] + a[1]*b[1] + a[2]*b[2] + a[3]*b[3];

  static List<double> _lerp(List<double> a, List<double> b, double t) {
    final r = List<double>.generate(4, (i) => a[i] + (b[i] - a[i]) * t);
    final n = math.sqrt(r.fold(0.0, (s, v) => s + v * v));
    return n < 1e-8 ? a : r.map((v) => v / n).toList();
  }
  // ────────────────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _breathe = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);

    _wvc = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.transparent)
      ..setNavigationDelegate(NavigationDelegate(
        onPageFinished: (_) {
          setState(() => _webReady = true);
          // Background synced in build() once context is available.
        },
      ))
      ..loadFlutterAsset('assets/web/spine_viewer.html');
  }

  @override
  void dispose() {
    _breathe.dispose();
    super.dispose();
  }

  void _calibrate(Map<String, List<double>> quats) {
    setState(() => _neutralQuats = Map.from(quats));
  }

  // Sends the scaffold background color to Three.js so it matches the app theme.
  void _syncBackground(BuildContext context) {
    if (!_webReady) return;
    final c = Theme.of(context).scaffoldBackgroundColor;
    final hex = c.r.round().toRadixString(16).padLeft(2, '0') +
                c.g.round().toRadixString(16).padLeft(2, '0') +
                c.b.round().toRadixString(16).padLeft(2, '0');
    _wvc.runJavaScript("setBackground('#$hex')");
  }

  void _sendToWebView(Map<String, List<double>> quats) {
    if (!_webReady) return;
    final pts = SpineKinematics.compute(quats, neutralQuats: _neutralQuats);
    final buf = StringBuffer('[');
    for (int i = 0; i < pts.length; i++) {
      if (i > 0) buf.write(',');
      buf.write('${pts[i].x.toStringAsFixed(4)},${pts[i].y.toStringAsFixed(4)},${pts[i].z.toStringAsFixed(4)}');
    }
    buf.write(']');
    _wvc.runJavaScript('updateSpine(${buf.toString()})');
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionProvider);
    final quats   = ref.watch(latestQuatsProvider);

    // Sync scene background to app theme on first ready frame and on rebuilds.
    if (_webReady) _syncBackground(context);

    ref.listen<Map<String, List<double>>?>(latestQuatsProvider, (prev, next) {
      if (next == null) return;

      // Auto-calibrate on the first data frame of each session.
      if (!_autoCalibrated) {
        _autoCalibrated = true;
        _calibrate(next);
        _sendToWebView(next);
        return;
      }

      // Adaptive drift correction: while sensors are still, gradually pull
      // the neutral reference towards the current reading to cancel gyro drift.
      final neutral = _neutralQuats;
      if (prev != null && neutral != null) {
        final allStill = next.keys.every((id) {
          final qP = prev[id], qC = next[id];
          return qP == null || qC == null || _dot(qP, qC).abs() > _stillDot;
        });
        if (allStill) {
          setState(() {
            _neutralQuats = {
              for (final id in next.keys)
                id: _lerp(neutral[id] ?? next[id]!, next[id]!, _driftRate),
            };
          });
        }
      }

      _sendToWebView(next);
    });

    // Reset calibration when session ends.
    ref.listen<SessionState>(sessionProvider, (_, next) {
      if (next.status == SessionStatus.idle && _autoCalibrated) {
        setState(() {
          _neutralQuats = null;
          _autoCalibrated = false;
        });
      }
    });

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            _Header(session: session),
            Expanded(
              child: quats == null || session.status == SessionStatus.idle
                  ? _IdleBody(status: session.status)
                  : _LiveBody(
                      quats: quats,
                      wvc: _wvc,
                      neutralQuats: _neutralQuats,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Header ───────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  const _Header({required this.session});
  final SessionState session;

  @override
  Widget build(BuildContext context) {
    final active = session.status == SessionStatus.active;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Live Spine Model',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '3D real-time model  ·  drag to rotate',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55),
                    fontSize: 13,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Theme.of(context).shadowColor.withValues(alpha: 0.06),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Icon(Icons.circle,
                    color: active
                        ? const Color(0xFF10B981)
                        : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
                    size: 10),
                const SizedBox(width: 8),
                Text(
                  active ? 'LIVE' : 'IDLE',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Idle state ────────────────────────────────────────────────────────────────

class _IdleBody extends StatelessWidget {
  const _IdleBody({required this.status});
  final SessionStatus status;

  @override
  Widget build(BuildContext context) {
    final starting = status == SessionStatus.starting;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            starting ? Icons.sensors : Icons.accessibility_new_rounded,
            size: 72,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.15),
          ),
          const SizedBox(height: 24),
          Text(
            starting ? 'Connecting to sensors…' : 'No active session',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (!starting) ...[
            const SizedBox(height: 8),
            Text(
              'Start a session from the Monitoring tab\nto see your live spine model.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.35),
                fontSize: 14,
                height: 1.5,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Live body ─────────────────────────────────────────────────────────────────

class _LiveBody extends StatelessWidget {
  const _LiveBody({
    required this.quats,
    required this.wvc,
    required this.neutralQuats,
  });
  final Map<String, List<double>> quats;
  final WebViewController wvc;
  final Map<String, List<double>>? neutralQuats;

  @override
  Widget build(BuildContext context) {
    final metrics = SpineKinematics.clinicalAngles(quats, neutralQuats: neutralQuats);

    return Column(
      children: [
        _MetricsRow(metrics: metrics),
        Expanded(
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            child: ColoredBox(
              color: Theme.of(context).scaffoldBackgroundColor,
              child: WebViewWidget(controller: wvc),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Metrics row ───────────────────────────────────────────────────────────────

class _MetricsRow extends StatelessWidget {
  const _MetricsRow({required this.metrics});
  final Map<String, double> metrics;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          _MetricCard(
            label: 'Lumbar\nLordosis',
            value: metrics['lumbarLordosis'] ?? 0,
            unit: '°',
            warnAbove: 60,
            icon: Icons.arrow_downward_rounded,
          ),
          const SizedBox(width: 8),
          _MetricCard(
            label: 'Thoracic\nKyphosis',
            value: metrics['thoracicKyphosis'] ?? 0,
            unit: '°',
            warnAbove: 50,
            icon: Icons.arrow_upward_rounded,
          ),
          const SizedBox(width: 8),
          _MetricCard(
            label: 'Cervical\nLordosis',
            value: metrics['cervicalLordosis'] ?? 0,
            unit: '°',
            warnAbove: 40,
            icon: Icons.arrow_downward_rounded,
          ),
          const SizedBox(width: 8),
          _MetricCard(
            label: 'Lateral\nDeviation',
            value: metrics['lateralDeviation'] ?? 0,
            unit: '°',
            warnAbove: 10,
            icon: Icons.swap_horiz_rounded,
          ),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.unit,
    required this.warnAbove,
    required this.icon,
  });

  final String label;
  final double value;
  final String unit;
  final double warnAbove;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final warn  = value > warnAbove;
    final color = warn ? const Color(0xFFEF4444) : Theme.of(context).primaryColor;

    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Theme.of(context).shadowColor.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(height: 4),
            Text(
              '${value.toStringAsFixed(1)}$unit',
              style: TextStyle(
                color: color,
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                fontSize: 10,
                fontWeight: FontWeight.w600,
                height: 1.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── SpinePainter ──────────────────────────────────────────────────────────────

class SpinePainter extends CustomPainter {
  SpinePainter({
    required this.points,
    required this.breatheScale,
    required this.primaryColor,
    required this.surfaceColor,
  });

  final List<SpinePoint3D> points;
  final double breatheScale;
  final Color primaryColor;
  final Color surfaceColor;

  // Sensor vertebra indices (mirrors SpineKinematics constants).
  static const _sensorIdx = {
    'L5': SpineKinematics.idxL5,
    'T12': SpineKinematics.idxT12,
    'T4': SpineKinematics.idxT4,
    'C7': SpineKinematics.idxC7,
  };

  @override
  void paint(Canvas canvas, Size size) {
    final halfW = size.width / 2;
    final dividerPaint = Paint()
      ..color = surfaceColor.withValues(alpha: 0.08)
      ..strokeWidth = 1;
    canvas.drawLine(Offset(halfW, 0), Offset(halfW, size.height), dividerPaint);

    _drawPanel(
      canvas,
      rect: Rect.fromLTWH(0, 0, halfW, size.height),
      label: 'SAGITTAL',
      sublabel: 'Side view',
      sagittal: true,
    );
    _drawPanel(
      canvas,
      rect: Rect.fromLTWH(halfW, 0, halfW, size.height),
      label: 'CORONAL',
      sublabel: 'Front view',
      sagittal: false,
    );
  }

  void _drawPanel(
    Canvas canvas, {
    required Rect rect,
    required String label,
    required String sublabel,
    required bool sagittal,
  }) {
    canvas.save();
    canvas.clipRect(rect);

    // Layout constants.
    const topPad   = 32.0;
    const botPad   = 16.0;
    final cx       = rect.left + rect.width / 2;
    final breatheFactor = 0.96 + breatheScale * 0.04; // subtle 4% oscillation
    final chainH   = (rect.height - topPad - botPad) * 0.92 * breatheFactor;
    final sacralY  = rect.top + rect.height - botPad - 8;
    final scale    = chainH; // 1 normalized unit = chainH pixels
    final hScale   = scale * 2.5; // amplify horizontal deflections for readability

    // Reference line (neutral straight spine).
    canvas.drawLine(
      Offset(cx, sacralY),
      Offset(cx, sacralY - chainH),
      Paint()
        ..color = surfaceColor.withValues(alpha: 0.06)
        ..strokeWidth = 1.5
        ..style = PaintingStyle.stroke,
    );

    // Map 3D points to 2D screen coordinates.
    Offset project(SpinePoint3D p) {
      final h = sagittal ? p.x : p.z;
      return Offset(cx + h * hScale, sacralY - p.y * scale);
    }

    final pts2d = points.map(project).toList();

    // Body silhouette drawn behind the spine.
    _drawBodySilhouette(canvas, pts2d, sagittal, scale, rect);

    // Draw smooth Catmull-Rom spine curve.
    _drawSplineCurve(canvas, pts2d);

    // Draw vertebral blocks oriented perpendicular to the spine direction.
    for (int i = 0; i < pts2d.length; i++) {
      final prev     = i > 0 ? pts2d[i - 1] : pts2d[i];
      final next     = i < pts2d.length - 1 ? pts2d[i + 1] : pts2d[i];
      final tangent  = next - prev;
      final isSensor = _sensorIdx.values.contains(i);
      final color    = _levelColor(i);

      // Block width by region: lumbar widest, cervical narrowest.
      final blockW = isSensor ? 16.0
          : (i == 0                           ? 13.0   // sacrum
          :  i < SpineKinematics.idxT12      ? 13.0   // lumbar
          :  i < SpineKinematics.idxT4       ? 11.0   // thoracic
          :  i < SpineKinematics.idxC7       ? 10.0   // upper thoracic
          :                                    8.0);  // cervical

      _drawVertebraBlock(canvas, pts2d[i], tangent, blockW, 5.5, color, isSensor);
    }

    // Sensor labels.
    _sensorIdx.forEach((name, idx) {
      _drawLabel(canvas, pts2d[idx], name, rect, sagittal);
    });

    // Panel title.
    _drawPanelTitle(canvas, rect, label, sublabel);

    canvas.restore();
  }

  // Catmull-Rom → cubic Bézier smooth curve, colored by region.
  void _drawSplineCurve(Canvas canvas, List<Offset> pts) {
    if (pts.length < 2) return;

    Offset ghost(int i) {
      if (i < 0) return Offset(2 * pts[0].dx - pts[1].dx, 2 * pts[0].dy - pts[1].dy);
      if (i >= pts.length) {
        return Offset(
          2 * pts.last.dx - pts[pts.length - 2].dx,
          2 * pts.last.dy - pts[pts.length - 2].dy,
        );
      }
      return pts[i];
    }

    for (int i = 0; i < pts.length - 1; i++) {
      final p0 = ghost(i - 1);
      final p1 = pts[i];
      final p2 = pts[i + 1];
      final p3 = ghost(i + 2);

      final cp1 = Offset(p1.dx + (p2.dx - p0.dx) / 6, p1.dy + (p2.dy - p0.dy) / 6);
      final cp2 = Offset(p2.dx - (p3.dx - p1.dx) / 6, p2.dy - (p3.dy - p1.dy) / 6);

      final col = Color.lerp(_levelColor(i), _levelColor(i + 1), 0.5)!
          .withValues(alpha: 0.85);

      final path = Path()
        ..moveTo(p1.dx, p1.dy)
        ..cubicTo(cp1.dx, cp1.dy, cp2.dx, cp2.dy, p2.dx, p2.dy);

      canvas.drawPath(
        path,
        Paint()
          ..color = col
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  // ── Vertebra block ──────────────────────────────────────────────────────────

  void _drawVertebraBlock(Canvas canvas, Offset center, Offset tangent,
      double blockW, double blockH, Color color, bool isSensor) {
    final len = math.sqrt(tangent.dx * tangent.dx + tangent.dy * tangent.dy);
    if (len < 0.01) return;
    // tx/ty: along spine direction; px/py: perpendicular (across vertebra)
    final tx = tangent.dx / len, ty = tangent.dy / len;
    final px = -ty, py = tx;
    final hw = blockW / 2, hh = blockH / 2;

    // Rounded-rect vertebral body using canvas rotation.
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(math.atan2(tangent.dy, tangent.dx) - math.pi / 2);
    final rRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset.zero, width: blockW, height: blockH),
      const Radius.circular(1.5),
    );
    canvas.drawRRect(rRect, Paint()..color = color..style = PaintingStyle.fill);
    // Subtle top-edge highlight for a slight 3-D look.
    canvas.drawRRect(rRect, Paint()
      ..color = Colors.white.withValues(alpha: isSensor ? 0.40 : 0.22)
      ..style = PaintingStyle.stroke
      ..strokeWidth = isSensor ? 1.2 : 0.7);
    canvas.restore();

    // Outer ring for sensor-position blocks.
    if (isSensor) {
      final ex = 3.5;
      final ring = Path()
        ..moveTo(center.dx + px * (hw + ex) + tx * (hh + ex),
                 center.dy + py * (hw + ex) + ty * (hh + ex))
        ..lineTo(center.dx - px * (hw + ex) + tx * (hh + ex),
                 center.dy - py * (hw + ex) + ty * (hh + ex))
        ..lineTo(center.dx - px * (hw + ex) - tx * (hh + ex),
                 center.dy - py * (hw + ex) - ty * (hh + ex))
        ..lineTo(center.dx + px * (hw + ex) - tx * (hh + ex),
                 center.dy + py * (hw + ex) - ty * (hh + ex))
        ..close();
      canvas.drawPath(ring, Paint()
        ..color = color.withValues(alpha: 0.45)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4);
    }
  }

  // ── Body silhouette ─────────────────────────────────────────────────────────

  void _drawBodySilhouette(Canvas canvas, List<Offset> pts2d,
      bool sagittal, double scale, Rect rect) {
    final fill = Paint()
      ..color = const Color(0xFFD4A574).withValues(alpha: 0.11)
      ..style = PaintingStyle.fill;
    final stroke = Paint()
      ..color = surfaceColor.withValues(alpha: 0.14)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    if (sagittal) {
      _drawSagittalBody(canvas, pts2d, scale, fill, stroke);
    } else {
      _drawCoronalBody(canvas, pts2d, scale, rect.width, fill, stroke);
    }
  }

  void _drawCoronalBody(Canvas canvas, List<Offset> pts2d,
      double scale, double panelW, Paint fill, Paint stroke) {
    final c1  = pts2d[SpineKinematics.numLevels - 1];
    final c7  = pts2d[SpineKinematics.idxC7];
    final t4  = pts2d[SpineKinematics.idxT4];
    final t12 = pts2d[SpineKinematics.idxT12];
    final l5  = pts2d[SpineKinematics.idxL5];
    final s1  = pts2d[0];

    // Widths relative to panel half-width so they always fit.
    final hr = panelW * 0.15;   // head radius
    final nw = panelW * 0.07;   // neck half-width
    final sw = panelW * 0.40;   // shoulder half-width
    final cw = panelW * 0.30;   // chest half-width
    final ww = panelW * 0.21;   // waist half-width
    final hw = panelW * 0.32;   // hip half-width
    final bw = panelW * 0.26;   // pelvis-base half-width

    // Head
    final headC = Offset(c1.dx, c1.dy - hr);
    canvas.drawOval(
      Rect.fromCenter(center: headC, width: hr * 2.0, height: hr * 2.2),
      fill);
    canvas.drawOval(
      Rect.fromCenter(center: headC, width: hr * 2.0, height: hr * 2.2),
      stroke);

    // Neck
    final neck = Path()
      ..moveTo(c7.dx - nw, c7.dy)
      ..lineTo(c7.dx - nw, headC.dy + hr)
      ..lineTo(c7.dx + nw, headC.dy + hr)
      ..lineTo(c7.dx + nw, c7.dy)
      ..close();
    canvas.drawPath(neck, fill);

    // Torso (right side then mirrored left)
    final body = Path();
    body.moveTo(c7.dx + nw, c7.dy);
    // right shoulder
    body.quadraticBezierTo(c7.dx + sw * 0.6, c7.dy - 6,  c7.dx + sw,  c7.dy + 8);
    // right armpit → chest
    body.quadraticBezierTo(c7.dx + sw, c7.dy + (t4.dy - c7.dy) * 0.5, t4.dx + cw,  t4.dy);
    // chest → waist
    body.quadraticBezierTo(t12.dx + cw * 0.8, (t4.dy + t12.dy) * 0.6,  t12.dx + ww, t12.dy);
    // waist → hip
    body.quadraticBezierTo(l5.dx + ww * 1.1,  (t12.dy + l5.dy) * 0.5,  l5.dx + hw,  l5.dy);
    // hip → pelvis bottom right
    body.quadraticBezierTo(s1.dx + bw, s1.dy,  s1.dx + bw * 0.3, s1.dy + 14);
    // crotch
    body.quadraticBezierTo(s1.dx, s1.dy + 22, s1.dx - bw * 0.3, s1.dy + 14);
    // left side (mirror)
    body.quadraticBezierTo(s1.dx - bw, s1.dy,  l5.dx - hw,  l5.dy);
    body.quadraticBezierTo(t12.dx - ww * 1.1, (t12.dy + l5.dy) * 0.5,  t12.dx - ww, t12.dy);
    body.quadraticBezierTo(t4.dx  - cw * 0.8, (t4.dy  + t12.dy) * 0.6, t4.dx - cw,  t4.dy);
    body.quadraticBezierTo(c7.dx - sw, c7.dy + (t4.dy - c7.dy) * 0.5,  c7.dx - sw,  c7.dy + 8);
    body.quadraticBezierTo(c7.dx - sw * 0.6, c7.dy - 6, c7.dx - nw, c7.dy);
    body.close();
    canvas.drawPath(body, fill);
    canvas.drawPath(body, stroke);
  }

  void _drawSagittalBody(Canvas canvas, List<Offset> pts2d,
      double scale, Paint fill, Paint stroke) {
    final c1  = pts2d[SpineKinematics.numLevels - 1];
    final c7  = pts2d[SpineKinematics.idxC7];
    final t4  = pts2d[SpineKinematics.idxT4];
    final t12 = pts2d[SpineKinematics.idxT12];
    final l5  = pts2d[SpineKinematics.idxL5];
    final s1  = pts2d[0];

    // Anterior-posterior offsets relative to spine chain height.
    final backOff  = scale * 0.05;   // posterior surface behind spine
    final chestOff = scale * 0.11;   // chest protrudes forward from T4
    final abdOff   = scale * 0.08;   // abdomen at T12/L5
    final pelOff   = scale * 0.06;   // pelvis front

    final hr = scale * 0.08;
    final headC = Offset(c1.dx + scale * 0.015, c1.dy - hr);

    // Head
    canvas.drawOval(
      Rect.fromCenter(center: headC, width: hr * 1.8, height: hr * 2.1), fill);
    canvas.drawOval(
      Rect.fromCenter(center: headC, width: hr * 1.8, height: hr * 2.1), stroke);

    // Torso: posterior side going down, then anterior side coming up.
    final body = Path();
    // --- posterior (back surface) ---
    body.moveTo(c7.dx - backOff, headC.dy + hr);
    body.quadraticBezierTo(
      c7.dx - backOff * 1.2, (c7.dy + t4.dy) / 2,
      t4.dx - backOff, t4.dy);
    body.quadraticBezierTo(
      t12.dx - backOff * 0.9, (t4.dy + t12.dy) / 2,
      t12.dx - backOff, t12.dy);
    body.quadraticBezierTo(          // lumbar lordosis curve
      l5.dx - backOff * 1.3, (t12.dy + l5.dy) / 2,
      l5.dx - backOff, l5.dy);
    body.quadraticBezierTo(          // buttock
      s1.dx - backOff * 0.8, s1.dy + 4,
      s1.dx, s1.dy + 16);
    // --- anterior (front surface) ---
    body.quadraticBezierTo(
      s1.dx + pelOff * 1.2, s1.dy + 10,
      l5.dx + pelOff, l5.dy);
    body.quadraticBezierTo(
      t12.dx + abdOff, (l5.dy + t12.dy) / 2,
      t12.dx + abdOff, t12.dy);
    body.quadraticBezierTo(          // chest bulge
      t4.dx + chestOff * 1.05, (t12.dy + t4.dy) / 2,
      t4.dx + chestOff, t4.dy);
    body.quadraticBezierTo(
      c7.dx + chestOff * 0.7, (t4.dy + c7.dy) / 2,
      c7.dx + scale * 0.03, c7.dy);
    body.quadraticBezierTo(          // neck front
      c7.dx + scale * 0.025, (c7.dy + headC.dy + hr) / 2,
      headC.dx - hr * 0.1, headC.dy + hr);
    body.close();
    canvas.drawPath(body, fill);
    canvas.drawPath(body, stroke);
  }

  // Color gradient: sacrum grey → lumbar red → thoracic yellow → cervical blue.
  Color _levelColor(int level) {
    if (level == 0) return const Color(0xFF6B7280);
    if (level <= SpineKinematics.idxL5) return const Color(0xFFEF4444);
    if (level <= SpineKinematics.idxT12) {
      return Color.lerp(
          const Color(0xFFEF4444), const Color(0xFFF59E0B),
          (level - SpineKinematics.idxL5) / (SpineKinematics.idxT12 - SpineKinematics.idxL5))!;
    }
    if (level <= SpineKinematics.idxT4) {
      return Color.lerp(
          const Color(0xFFF59E0B), const Color(0xFF06B6D4),
          (level - SpineKinematics.idxT12) / (SpineKinematics.idxT4 - SpineKinematics.idxT12))!;
    }
    if (level <= SpineKinematics.idxC7) {
      return Color.lerp(
          const Color(0xFF06B6D4), const Color(0xFF3B82F6),
          (level - SpineKinematics.idxT4) / (SpineKinematics.idxC7 - SpineKinematics.idxT4))!;
    }
    return const Color(0xFF3B82F6);
  }

  void _drawLabel(Canvas canvas, Offset pos, String text, Rect panel, bool sagittal) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: surfaceColor.withValues(alpha: 0.55),
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    // Place label to the right of the node, flip to left if near right edge.
    double lx = pos.dx + 10;
    if (lx + tp.width > panel.right - 4) lx = pos.dx - tp.width - 10;

    tp.paint(canvas, Offset(lx, pos.dy - tp.height / 2));
  }

  void _drawPanelTitle(Canvas canvas, Rect rect, String title, String sub) {
    final tp = TextPainter(
      text: TextSpan(
        children: [
          TextSpan(
            text: '$title\n',
            style: TextStyle(
              color: surfaceColor.withValues(alpha: 0.45),
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
            ),
          ),
          TextSpan(
            text: sub,
            style: TextStyle(
              color: surfaceColor.withValues(alpha: 0.25),
              fontSize: 9,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    )..layout(maxWidth: rect.width);

    tp.paint(canvas, Offset(rect.left + (rect.width - tp.width) / 2, rect.top + 8));
  }

  @override
  bool shouldRepaint(covariant SpinePainter old) =>
      old.points != points || old.breatheScale != breatheScale;
}
