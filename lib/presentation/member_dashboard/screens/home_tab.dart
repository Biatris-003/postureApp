import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/datasources/ble_service_mock.dart';
import '../../../data/datasources/ml_classifier_service_mock.dart';

class HomeTab extends ConsumerStatefulWidget {
  const HomeTab({super.key});

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
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
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
                  _buildHeader(context),
                  const SizedBox(height: 48),
                  _buildCentralAvatar(context, isUpright, postureData.postureClass),
                  const SizedBox(height: 64),
                  _buildPostureScoreSlider(context, postureData.confidence, isUpright),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Good Morning,', 
              style: TextStyle(fontSize: 16, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6), fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 4),
            Text('Sarah Connor', 
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, letterSpacing: -0.5, color: Theme.of(context).colorScheme.onSurface),
            ),
          ],
        ),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(color: Theme.of(context).shadowColor.withValues(alpha: 0.05), blurRadius: 15, offset: const Offset(0, 5)),
            ],
          ),
          child: Icon(Icons.notifications_none, color: Theme.of(context).colorScheme.onSurface),
        ),
      ],
    );
  }

  Widget _buildCentralAvatar(BuildContext context, bool isUpright, String postureClass) {
    // Mapping 6 postures to specific colors and assets
    final Map<String, Color> statusColors = {
      'Upright': const Color(0xFF10B981),
      'Slouching': const Color(0xFFEF4444),
      'Forward Bending': const Color(0xFFF59E0B),
      'Backward Bending': const Color(0xFF8B5CF6),
      'Left Bending': const Color(0xFF3B82F6),
      'Right Bending': const Color(0xFF06B6D4),
    };

    final Map<String, String> avatarPaths = {
      'Upright': 'assets/images/Upright.jpeg',
      'Slouching': 'assets/images/Slouching.jpeg',
      'Forward Bending': 'assets/images/Forward Bending.jpeg',
      'Backward Bending': 'assets/images/Backward Bending.jpeg',
      'Left Bending': 'assets/images/Left Bending.jpeg',
      'Right Bending': 'assets/images/Right Bending.jpeg',
    };

    final Map<String, String> exactTexts = {
      'Upright': 'Upright Posture',
      'Slouching': 'Slouching',
      'Forward Bending': 'Forward Bending',
      'Backward Bending': 'Backward Bending',
      'Left Bending': 'Left Bending',
      'Right Bending': 'Right Bending',
    };

    final Map<String, IconData> statusIcons = {
      'Upright': Icons.check_circle_rounded,
      'Slouching': Icons.warning_rounded,
      'Forward Bending': Icons.arrow_upward_rounded,
      'Backward Bending': Icons.arrow_downward_rounded,
      'Left Bending': Icons.arrow_back_rounded,
      'Right Bending': Icons.arrow_forward_rounded,
    };

    final Color statusColor = statusColors[postureClass] ?? (isUpright ? const Color(0xFF10B981) : const Color(0xFFEF4444));
    final String avatarPath = avatarPaths[postureClass] ?? (isUpright ? 'assets/images/Upright.jpeg' : 'assets/images/Slouching.jpeg');
    final IconData statusIcon = statusIcons[postureClass] ?? (isUpright ? Icons.check_circle_rounded : Icons.warning_rounded);
    final String displayText = exactTexts[postureClass] ?? postureClass;

    return Center(
      child: Column(
        children: [
          AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              return Container(
                width: 280,
                height: 280,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Theme.of(context).cardColor,
                  boxShadow: [
                    BoxShadow(
                      color: statusColor.withValues(alpha: 0.15 * _pulseController.value),
                      blurRadius: 40,
                      spreadRadius: 10 * _pulseController.value,
                    ),
                    BoxShadow(
                      color: Theme.of(context).shadowColor.withValues(alpha: 0.08), 
                      blurRadius: 30, 
                      offset: const Offset(0, 15),
                    ),
                  ],
                  border: Border.all(color: statusColor.withValues(alpha: 0.3), width: 4),
                ),
                child: ClipOval(
                  child: Image.asset(
                    avatarPath,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) => Container(
                      color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                      child: Icon(Icons.person_rounded, size: 100, color: Theme.of(context).primaryColor.withValues(alpha: 0.5)),
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(30),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  statusIcon,
                  color: statusColor,
                  size: 24,
                ),
                const SizedBox(width: 8),
                Text(
                  displayText,
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                    fontSize: 18,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPostureScoreSlider(BuildContext context, double confidence, bool isUpright) {
    // Generate a mock score based on confidence and upright state 
    // Score is 0 to 100. Upright is 80-100. Non-upright is 0-79.
    double score = isUpright ? 80 + (confidence * 20) : (1.0 - confidence) * 79;
    Color sliderColor = Theme.of(context).primaryColor;
    
    if (score > 80) {
      sliderColor = const Color(0xFF10B981);
    } else if (score > 50) sliderColor = const Color(0xFFF59E0B);
    else sliderColor = const Color(0xFFEF4444);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(color: Theme.of(context).shadowColor.withValues(alpha: 0.05), blurRadius: 20, offset: const Offset(0, 10))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'Posture Score',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: Theme.of(context).colorScheme.onSurface,
                  letterSpacing: -0.5,
                ),
              ),
              Text(
                '${score.toInt()}',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  color: sliderColor,
                  height: 1.0,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Stack(
            children: [
              // Background track
              Container(
                height: 16,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              // Filled track
              AnimatedContainer(
                duration: const Duration(milliseconds: 500),
                curve: Curves.easeOutCubic,
                height: 16,
                width: MediaQuery.of(context).size.width * (score / 100).clamp(0.0, 1.0) * 0.75, // Approximating width relative to screen padding
                decoration: BoxDecoration(
                  color: sliderColor,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: sliderColor.withValues(alpha: 0.4),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    )
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Poor', style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4), fontWeight: FontWeight.w600, fontSize: 12)),
              Text('Fair', style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4), fontWeight: FontWeight.w600, fontSize: 12)),
              Text('Optimal', style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4), fontWeight: FontWeight.w600, fontSize: 12)),
            ],
          )
        ],
      ),
    );
  }
}

