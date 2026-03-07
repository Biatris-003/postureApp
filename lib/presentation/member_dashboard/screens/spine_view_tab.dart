import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:math';

import '../../../data/datasources/ble_service_mock.dart';
import '../../../data/datasources/ml_classifier_service_mock.dart';

class SpineViewTab extends ConsumerStatefulWidget {
  const SpineViewTab({Key? key}) : super(key: key);

  @override
  ConsumerState<SpineViewTab> createState() => _SpineViewTabState();
}

class _SpineViewTabState extends ConsumerState<SpineViewTab> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _breatheAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
        vsync: this, duration: const Duration(seconds: 3))..repeat(reverse: true);
    
    _breatheAnimation = Tween<double>(begin: 0.98, end: 1.02).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOutSine)
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bleService = ref.watch(bleServiceProvider);
    final mlService = ref.watch(mlClassifierServiceProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A), // Dark blueprint background
      body: StreamBuilder<List<double>>(
        stream: bleService.sensorDataStream,
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          final rawData = snapshot.data!;
          final isUpright = mlService.classify(rawData).postureClass == 'Upright';
          
          // Generate mock physiological parameters from sensor data
          // Normal cervical lordosis is ~20-40 deg. Normal thoracic kyphosis is ~20-40.
          // We map the mock sensor data (0 to 1) to these angles.
          double mockSensorVal = rawData.isNotEmpty ? rawData[0] : 0.5;
          
          double cervicalAngle = 30 + (mockSensorVal * 15 * (isUpright ? 0.2 : 1.0)); 
          double thoracicAngle = 35 + (mockSensorVal * 20 * (isUpright ? 0.1 : 1.2));

          return SafeArea(
            child: Stack(
              children: [
                _buildGridBackground(),
                Column(
                  children: [
                    _buildHeader(),
                    Expanded(
                      child: Row(
                        children: [
                          _buildMetricsPanel(cervicalAngle, thoracicAngle, isUpright),
                          Expanded(
                            flex: 2,
                            child: AnimatedBuilder(
                              animation: _breatheAnimation,
                              builder: (context, child) {
                                return Transform.scale(
                                  scale: _breatheAnimation.value,
                                  child: CustomPaint(
                                    size: const Size(double.infinity, double.infinity),
                                    painter: SpinePainter(
                                        cervicalAngle: cervicalAngle,
                                        thoracicAngle: thoracicAngle,
                                        isUpright: isUpright),
                                  ),
                                );
                              }
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildGridBackground() {
    return CustomPaint(
      size: const Size(double.infinity, double.infinity),
      painter: GridPainter(),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Live Spine Model', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
              SizedBox(height: 4),
              Text('Real-time sagittal plane projection', style: TextStyle(color: Colors.blueAccent, fontSize: 14)),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(color: Colors.blueAccent.withOpacity(0.2), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.blueAccent.withOpacity(0.5))),
            child: const Row(
              children: [
                Icon(Icons.circle, color: Colors.greenAccent, size: 10),
                SizedBox(width: 6),
                Text('REC', style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 12)),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildMetricsPanel(double cervical, double thoracic, bool isUpright) {
    return Container(
      width: 140,
      padding: const EdgeInsets.only(left: 24, top: 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildMetric('Cervical Lordosis', '${cervical.toStringAsFixed(1)}°', cervical > 40 ? Colors.redAccent : Colors.white),
          const SizedBox(height: 40),
          _buildMetric('Thoracic Kyphosis', '${thoracic.toStringAsFixed(1)}°', thoracic > 50 ? Colors.orangeAccent : Colors.white),
          const SizedBox(height: 40),
          _buildMetric('Lumbar Lordosis', '42.0°', Colors.white), // Static mock for aesthetics
          const Spacer(),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isUpright ? Colors.greenAccent.withOpacity(0.1) : Colors.redAccent.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: isUpright ? Colors.greenAccent : Colors.redAccent, width: 1)
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(isUpright ? Icons.check_circle_outline : Icons.warning_amber_rounded, color: isUpright ? Colors.greenAccent : Colors.redAccent),
                const SizedBox(height: 8),
                Text(isUpright ? 'Alignment Optimal' : 'Deviation Detected', style: TextStyle(color: isUpright ? Colors.greenAccent : Colors.redAccent, fontSize: 12, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildMetric(String label, String value, Color valueColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value, style: TextStyle(color: valueColor, fontSize: 28, fontWeight: FontWeight.bold, fontFamily: 'monospace')),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
      ],
    );
  }
}

class GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    var paint = Paint()
      ..color = Colors.blue.withOpacity(0.05)
      ..strokeWidth = 1.0;

    for (double i = 0; i < size.width; i += 30) canvas.drawLine(Offset(i, 0), Offset(i, size.height), paint);
    for (double i = 0; i < size.height; i += 30) canvas.drawLine(Offset(0, i), Offset(size.width, i), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class SpinePainter extends CustomPainter {
  final double cervicalAngle;
  final double thoracicAngle;
  final bool isUpright;

  SpinePainter({required this.cervicalAngle, required this.thoracicAngle, required this.isUpright});

  @override
  void paint(Canvas canvas, Size size) {
    final double centerX = size.width / 2;
    final double topY = size.height * 0.1;
    final double bottomY = size.height * 0.9;
    final double totalHeight = bottomY - topY;

    // Define control points for the bezier curve representing the spine
    // We use the angle parameters to push the control points left/right
    
    double cervicalOffset = (cervicalAngle - 30) * 2.0; // exaggerated for visual effect
    double thoracicOffset = (thoracicAngle - 35) * 3.0;

    Offset p0 = Offset(centerX + 20, topY); // Base of skull
    Offset p1 = Offset(centerX - 40 - cervicalOffset, topY + totalHeight * 0.2); // Cervical curve (lordosis - curves forward/left)
    Offset p2 = Offset(centerX + 60 + thoracicOffset, topY + totalHeight * 0.5); // Thoracic curve (kyphosis - curves backward/right)
    Offset p3 = Offset(centerX - 30, topY + totalHeight * 0.8); // Lumbar curve 
    Offset p4 = Offset(centerX + 10, bottomY); // Sacrum

    // Draw the main spline
    var linePaint = Paint()
      ..color = isUpright ? Colors.blueAccent.withOpacity(0.8) : Colors.redAccent.withOpacity(0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6.0
      ..strokeCap = StrokeCap.round;

    var path = Path();
    path.moveTo(p0.dx, p0.dy);
    // Use cubic beziers for smooth continuous curves
    path.cubicTo(p1.dx, p1.dy, p2.dx, p2.dy - totalHeight * 0.1, p2.dx, p2.dy);
    path.cubicTo(p2.dx, p2.dy + totalHeight * 0.1, p3.dx, p3.dy, p4.dx, p4.dy);

    canvas.drawPath(path, linePaint);

    // Draw "Vertebrae" nodes along the path
    var nodePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
      
    var borderPaint = Paint()
      ..color = const Color(0xFF0F172A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    // Sample points along the path to draw nodes (approximated for simplicity)
    int numNodes = 24; // 7 cervical, 12 thoracic, 5 lumbar
    
    // Extracted path metrics can be used, but for simplicity we'll interpolate mathematically
    for (int i = 0; i <= numNodes; i++) {
      double t = i / numNodes;
      Offset pos = _calculateCubicBezier(t, p0, p1, p2, p3, p4, totalHeight);
      
      canvas.drawCircle(pos, 6.0, nodePaint);
      canvas.drawCircle(pos, 6.0, borderPaint);
    }
    
    // Draw skull indicator
    canvas.drawCircle(p0, 15.0, Paint()..color = Colors.blueGrey..style = PaintingStyle.stroke..strokeWidth = 3);
    
    // Draw Sacrum indicator
    var sacrumPath = Path()
      ..moveTo(p4.dx - 15, p4.dy)
      ..lineTo(p4.dx + 15, p4.dy)
      ..lineTo(p4.dx, p4.dy + 30)
      ..close();
    canvas.drawPath(sacrumPath, Paint()..color = Colors.blueGrey..style = PaintingStyle.stroke..strokeWidth = 3);

  }
  
  // Custom interpolation for a multi-segment cubic bezier
  Offset _calculateCubicBezier(double t, Offset p0, Offset p1, Offset p2, Offset p3, Offset p4, double h) {
    if (t < 0.5) {
      double localT = t * 2;
      return _cubic(localT, p0, p1, Offset(p2.dx, p2.dy - h * 0.1), p2);
    } else {
      double localT = (t - 0.5) * 2;
      return _cubic(localT, p2, Offset(p2.dx, p2.dy + h * 0.1), p3, p4);
    }
  }
  
  Offset _cubic(double t, Offset p0, Offset p1, Offset p2, Offset p3) {
    double u = 1 - t;
    double tt = t * t;
    double uu = u * u;
    double uuu = uu * u;
    double ttt = tt * t;

    double x = uuu * p0.dx + 3 * uu * t * p1.dx + 3 * u * tt * p2.dx + ttt * p3.dx;
    double y = uuu * p0.dy + 3 * uu * t * p1.dy + 3 * u * tt * p2.dy + ttt * p3.dy;
    return Offset(x, y);
  }

  @override
  bool shouldRepaint(covariant SpinePainter oldDelegate) {
    return oldDelegate.cervicalAngle != cervicalAngle || 
           oldDelegate.thoracicAngle != thoracicAngle ||
           oldDelegate.isUpright != isUpright;
  }
}
