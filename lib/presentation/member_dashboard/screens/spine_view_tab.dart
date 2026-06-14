import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/datasources/ble_service_mock.dart';
import '../../../data/datasources/ml_classifier_service_mock.dart';

class SpineViewTab extends ConsumerStatefulWidget {
  const SpineViewTab({super.key});

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
    
    final primaryColor = Theme.of(context).primaryColor;
    final onSurfaceColor = Theme.of(context).colorScheme.onSurface;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: StreamBuilder<List<double>>(
        stream: bleService.sensorDataStream,
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          final rawData = snapshot.data!;
          final isUpright = mlService.classify(rawData).postureClass == 'Upright';
          
          double mockSensorVal = rawData.isNotEmpty ? rawData[0] : 0.5;
          double cervicalAngle = 30 + (mockSensorVal * 15 * (isUpright ? 0.2 : 1.0)); 
          double thoracicAngle = 35 + (mockSensorVal * 20 * (isUpright ? 0.1 : 1.2));

          return SafeArea(
            child: Stack(
              children: [
                _buildGridBackground(primaryColor),
                Column(
                  children: [
                    _buildHeader(context),
                    Expanded(
                      child: Row(
                        children: [
                          _buildMetricsPanel(context, cervicalAngle, thoracicAngle, isUpright),
                          Expanded(
                            flex: 2,
                            child: AnimatedBuilder(
                              animation: _breatheAnimation,
                              builder: (context, child) {
                                return Transform.scale(
                                  scale: _breatheAnimation.value,
                                  child: LayoutBuilder(
                                    builder: (context, constraints) {
                                      return Stack(
                                        alignment: Alignment.center,
                                        children: [
                                          // Realistic Anatomical Side-Profile Silhouette
                                          Opacity(
                                            opacity: 0.4,
                                            child: Image.asset(
                                              'assets/images/spine_silhouette.png',
                                              width: constraints.maxWidth * 0.95,
                                              height: constraints.maxHeight * 0.95,
                                              fit: BoxFit.contain,
                                              errorBuilder: (context, error, stackTrace) => Container(
                                                width: constraints.maxWidth * 0.95,
                                                height: constraints.maxHeight * 0.95,
                                                alignment: Alignment.center,
                                                child: Icon(
                                                  Icons.accessibility_new_rounded,
                                                  size: constraints.maxHeight * 0.4,
                                                  color: primaryColor.withValues(alpha: 0.1),
                                                ),
                                              ),
                                            ),
                                          ),
                                          // 3D Spine Visualization aligned to the silhouette's back
                                          IgnorePointer(
                                            child: SizedBox(
                                              width: constraints.maxWidth * 0.95,
                                              height: constraints.maxHeight * 0.95,
                                              child: CustomPaint(
                                              painter: SpinePainter(
                                                cervicalAngle: cervicalAngle,
                                                thoracicAngle: thoracicAngle,
                                                isUpright: isUpright,
                                                primaryColor: primaryColor,
                                                onSurfaceColor: onSurfaceColor,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      );
                                    },
                                  ),
                                );
                              },
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

  Widget _buildGridBackground(Color primaryColor) {
    return CustomPaint(
      size: const Size(double.infinity, double.infinity),
      painter: GridPainter(gridColor: primaryColor.withValues(alpha: 0.05)),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Live Spine Model', style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text('Real-time sagittal plane projection', style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6), fontSize: 14)),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor, 
              borderRadius: BorderRadius.circular(20), 
              boxShadow: [BoxShadow(color: Theme.of(context).shadowColor.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))]
            ),
            child: Row(
              children: [
                const Icon(Icons.circle, color: Color(0xFF10B981), size: 10),
                const SizedBox(width: 8),
                Text('REC', style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.w800, fontSize: 13, letterSpacing: 1)),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildMetricsPanel(BuildContext context, double cervical, double thoracic, bool isUpright) {
    return Container(
      width: 140, // Restored to original
      padding: const EdgeInsets.only(left: 24, top: 40), // Restored to original
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: IntrinsicHeight(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildMetric(context, 'Cervical Lordosis', '${cervical.toStringAsFixed(1)}°', cervical > 40 ? const Color(0xFFEF4444) : Theme.of(context).primaryColor),
                    const SizedBox(height: 40),
                    _buildMetric(context, 'Thoracic Kyphosis', '${thoracic.toStringAsFixed(1)}°', thoracic > 50 ? const Color(0xFFF59E0B) : Theme.of(context).primaryColor),
                    const SizedBox(height: 40),
                    _buildMetric(context, 'Lumbar Lordosis', '42.0°', Theme.of(context).primaryColor),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [BoxShadow(color: Theme.of(context).shadowColor.withValues(alpha: 0.05), blurRadius: 15, offset: const Offset(0, 5))]
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: isUpright ? const Color(0xFF10B981).withValues(alpha: 0.15) : const Color(0xFFEF4444).withValues(alpha: 0.15),
                              shape: BoxShape.circle
                            ),
                            child: Icon(isUpright ? Icons.check_circle_outline_rounded : Icons.warning_amber_rounded, color: isUpright ? const Color(0xFF10B981) : const Color(0xFFEF4444), size: 20),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            isUpright ? 'Alignment Optimal' : 'Deviation Detected',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurface,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              height: 1.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildMetric(BuildContext context, String label, String value, Color valueColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value, style: TextStyle(color: valueColor, fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
        const SizedBox(height: 6),
        Text(label, style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5), fontSize: 13, fontWeight: FontWeight.w600)),
      ],
    );
  }
}

class GridPainter extends CustomPainter {
  final Color gridColor;
  GridPainter({required this.gridColor});

  @override
  void paint(Canvas canvas, Size size) {
    var paint = Paint()
      ..color = gridColor
      ..strokeWidth = 1.0;

    for (double i = 0; i < size.width; i += 30) {
      canvas.drawLine(Offset(i, 0), Offset(i, size.height), paint);
    }
    for (double i = 0; i < size.height; i += 30) {
      canvas.drawLine(Offset(0, i), Offset(size.width, i), paint);
    }
  }

  @override
  bool shouldRepaint(covariant GridPainter oldDelegate) => oldDelegate.gridColor != gridColor;
}

class SpinePainter extends CustomPainter {
  final double cervicalAngle;
  final double thoracicAngle;
  final bool isUpright;
  final Color primaryColor;
  final Color onSurfaceColor;

  SpinePainter({required this.cervicalAngle, required this.thoracicAngle, required this.isUpright, required this.primaryColor, required this.onSurfaceColor});

  @override
  void paint(Canvas canvas, Size size) {
    // Lead factor: Aligning the spine vertically to the neck-to-sacrum region of the silhouette
    final double centerX = size.width / 2 + 15; // Shift to the right (back of the profile)
    final double topY = size.height * 0.30; // Start at the neck
    final double bottomY = size.height * 0.90; // End at the L5/Sacrum region
    final double totalHeight = bottomY - topY;

    double cervicalOffset = (cervicalAngle - 30) * 1.5; 
    double thoracicOffset = (thoracicAngle - 35) * 2.0;

    // Decrease the base curvature for the aligned (upright) spine to make it look healthier
    double curveScale = isUpright ? 0.4 : 1.0;
    // Increase thoracic outward curve just a little bit
    double thoracicCurveScale = isUpright ? 0.6 : 1.0;

    Offset p0 = Offset(centerX, topY); // Base of skull
    Offset p1 = Offset(centerX - (30 * curveScale) - cervicalOffset, topY + totalHeight * 0.2); 
    Offset p2 = Offset(centerX + (40 * thoracicCurveScale) + thoracicOffset, topY + totalHeight * 0.5); 
    Offset p3 = Offset(centerX - (20 * curveScale), topY + totalHeight * 0.8);  
    Offset p4 = Offset(centerX + (5 * curveScale), bottomY); // Sacrum

    // Draw the main spline - slimmer for realism
    var linePaint = Paint()
      ..color = isUpright ? primaryColor.withValues(alpha: 0.3) : const Color(0xFFEF4444).withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8.0
      ..strokeCap = StrokeCap.round;

    var path = Path();
    path.moveTo(p0.dx, p0.dy);
    path.cubicTo(p1.dx, p1.dy, p2.dx, p2.dy - totalHeight * 0.1, p2.dx, p2.dy);
    path.cubicTo(p2.dx, p2.dy + totalHeight * 0.1, p3.dx, p3.dy, p4.dx, p4.dy);

    canvas.drawPath(path, linePaint);

    // Draw "Vertebrae" nodes along the path
    var nodePaint = Paint()
      ..color = isUpright ? primaryColor : const Color(0xFFEF4444)
      ..style = PaintingStyle.fill;
      
    var borderPaint = Paint()
      ..color = onSurfaceColor == Colors.white ? const Color(0xFF1E1E1E) : Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;

    int numNodes = 24; 
    
    for (int i = 0; i <= numNodes; i++) {
      double t = i / numNodes;
      Offset pos = _calculateCubicBezier(t, p0, p1, p2, p3, p4, totalHeight);
      
      canvas.drawCircle(pos, 4.5, nodePaint);
      canvas.drawCircle(pos, 4.5, borderPaint);
    }
    
    // Draw skull indicator - smaller and more subtle
    canvas.drawCircle(p0, 12.0, Paint()..color = onSurfaceColor.withValues(alpha: 0.2)..style = PaintingStyle.stroke..strokeWidth = 3);
    
    // Draw Sacrum indicator - smaller
    var sacrumPath = Path()
      ..moveTo(p4.dx - 12, p4.dy)
      ..lineTo(p4.dx + 12, p4.dy)
      ..lineTo(p4.dx, p4.dy + 24)
      ..close();
    canvas.drawPath(sacrumPath, Paint()..color = onSurfaceColor.withValues(alpha: 0.2)..style = PaintingStyle.stroke..strokeWidth = 3);
  }
  
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
           oldDelegate.isUpright != isUpright ||
           oldDelegate.primaryColor != primaryColor ||
           oldDelegate.onSurfaceColor != onSurfaceColor;
  }
}
