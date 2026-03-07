import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/datasources/ble_service_mock.dart';
import '../../../data/datasources/ml_classifier_service_mock.dart';

class HomeTab extends ConsumerStatefulWidget {
  const HomeTab({Key? key}) : super(key: key);

  @override
  ConsumerState<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends ConsumerState<HomeTab> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bleService = ref.watch(bleServiceProvider);
    final mlService = ref.watch(mlClassifierServiceProvider);

    return Scaffold(
      backgroundColor: Colors.grey[50], // Clean light background
      body: StreamBuilder<List<double>>(
        stream: bleService.sensorDataStream,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final rawData = snapshot.data!;
          final postureData = mlService.classify(rawData);
          final isUpright = postureData.postureClass == 'Upright';

          return SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(),
                  const SizedBox(height: 48),
                  _buildStatusRing(isUpright, postureData.confidence),
                  const SizedBox(height: 48),
                  const Text('Live Sensor Data', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  _buildLiveSensorsGrid(rawData),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Good Morning,', style: TextStyle(fontSize: 16, color: Colors.grey, fontWeight: FontWeight.w500)),
            SizedBox(height: 4),
            Text('Sarah Connor', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, letterSpacing: -0.5)),
          ],
        ),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
          ),
          child: const Icon(Icons.notifications_none, color: Colors.black87),
        ),
      ],
    );
  }

  Widget _buildStatusRing(bool isUpright, double confidence) {
    Color ringColor = isUpright ? Colors.green.shade500 : Colors.red.shade500;
    Color glowColor = isUpright ? Colors.green.shade200 : Colors.red.shade200;

    return Center(
      child: AnimatedBuilder(
        animation: _pulseController,
        builder: (context, child) {
          return Container(
            width: 250,
            height: 250,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: glowColor.withOpacity(0.5 * _pulseController.value),
                  blurRadius: 40,
                  spreadRadius: 10 * _pulseController.value,
                ),
                BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, 10)),
              ],
              border: Border.all(color: ringColor, width: 8),
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    isUpright ? Icons.check_circle : Icons.warning_amber_rounded,
                    size: 48,
                    color: ringColor,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    isUpright ? 'Perfect\nPosture' : 'Posture\nDeviation',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      height: 1.2,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: ringColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'AI Confidence ${(confidence * 100).toInt()}%',
                      style: TextStyle(color: ringColor, fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  )
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildLiveSensorsGrid(List<double> rawData) {
    // Generate mock sensible data from the raw double array (pitch, roll, yaw)
    double pitch = (rawData.isNotEmpty ? rawData[0] : 0) * 90; // mock degrees
    double roll = (rawData.length > 1 ? rawData[1] : 0) * 45; 
    double yaw = (rawData.length > 2 ? rawData[2] : 0) * 360;

    return Row(
      children: [
        Expanded(child: _buildSensorCard('Pitch', '${pitch.toStringAsFixed(1)}°', Icons.screen_rotation_outlined, Colors.blue)),
        const SizedBox(width: 16),
        Expanded(child: _buildSensorCard('Roll', '${roll.toStringAsFixed(1)}°', Icons.rotate_right_outlined, Colors.orange)),
        const SizedBox(width: 16),
        Expanded(child: _buildSensorCard('Yaw', '${yaw.toStringAsFixed(1)}°', Icons.explore_outlined, Colors.purple)),
      ],
    );
  }

  Widget _buildSensorCard(String title, String value, IconData icon, MaterialColor color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: color.shade50, borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 16),
          Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: -0.5)),
          const SizedBox(height: 4),
          Text(title, style: TextStyle(color: Colors.grey.shade500, fontSize: 13, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
