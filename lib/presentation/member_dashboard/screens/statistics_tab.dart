import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../data/datasources/analytics_service.dart';
import '../../../domain/entities/posture_classification.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import '../../../data/datasources/auth_service_mock.dart';
import '../../../core/theme/app_theme.dart';
import 'dart:typed_data';

final analyticsServiceProvider = Provider((ref) => AnalyticsService());

// All possible posture keys (hardcoded list for iteration)
const _postureKeys = [
  'upright',
  'forward_bending',
  'right_bending',
  'left_bending',
  'backward_bending',
  'slouching',
];

// Posture display names
String _postureName(String key) {
  switch (key) {
    case 'upright':
      return 'Upright';
    case 'forward_bending':
      return 'Forward Bending';
    case 'right_bending':
      return 'Right Bending';
    case 'left_bending':
      return 'Left Bending';
    case 'backward_bending':
      return 'Backward Bending';
    case 'slouching':
      return 'Slouching';
    default:
      return key;
  }
}

Color _getDynamicPostureColor(String key, Map<String, double> percentages) {
  // Upright is ALWAYS the darkest color (best posture)
  if (key == 'upright') {
    return const Color(0xFF35506E); // primaryDeep - darkest
  }

  // Get all postures EXCEPT upright and sort by percentage (highest first)
  final sortedKeys = _postureKeys
      .where((k) => k != 'upright' && (percentages[k] ?? 0) > 0)
      .toList()
    ..sort((a, b) => (percentages[b] ?? 0).compareTo(percentages[a] ?? 0));

  // Find the index of the current key in the sorted list
  final index = sortedKeys.indexOf(key);
  
  // If not found, return a default color
  if (index == -1) {
    return const Color(0xFF7B8FB0);
  }

  // Map index to gradient colors (darkest for highest percentage)
  // The highest percentage among non-upright postures gets RED (danger)
  // Others get progressively lighter
  final gradientColors = [
    0xFFB3261E, // RED - highest percentage (most problematic)
    0xFFE05252, // lighter red
    0xFFF5A623, // orange
    0xFF7C96B3, // teal
    0xFF9BB0C9, // lightest
  ];

  final colorIndex = index < gradientColors.length ? index : gradientColors.length - 1;
  return Color(gradientColors[colorIndex]);
}

class StatisticsTab extends ConsumerStatefulWidget {
  const StatisticsTab({super.key});

  @override
  ConsumerState<StatisticsTab> createState() => _StatisticsTabState();
}

class _StatisticsTabState extends ConsumerState<StatisticsTab> {
  int _selectedTimeRange = 0;
  List<PostureClassification> _data = [];
  bool _isLoading = true;
  int? _touchedPieIndex;
  Timer? _pieResetTimer;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _pieResetTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final user = ref.read(authStateProvider);
    final firebaseUid = user?.userId;
    final service = ref.read(analyticsServiceProvider);

    try {
      if (firebaseUid == null) throw Exception('User not logged in');

      final patientId = await service.resolvePatientId(
        firebaseUid: firebaseUid,
        legacyUserId: user?.uid,
      );
      if (patientId == null) throw Exception('Patient record not found');

      List<PostureClassification> data;
      if (_selectedTimeRange == 0) {
        data = await service.getTodayClassifications(patientId);
      } else if (_selectedTimeRange == 1) {
        data = await service.getClassificationsByDays(patientId, 7);
      } else {
        data = await service.getClassificationsByDays(patientId, 30);
      }

      setState(() {
        _data = data;
        _isLoading = false;
        _touchedPieIndex = null;
      });

      if (_selectedTimeRange == 0 && data.isNotEmpty) {
        await service.saveDailyStatistics(patientId, data);
      }
    } catch (e) {
      debugPrint('❌ loadData error: $e');
      setState(() {
        _data = [];
        _isLoading = false;
      });
    }
  }

  // ── Shared card wrapper ──────────────────────────────────
  Widget _card({required Widget child, EdgeInsetsGeometry? padding}) {
    return Container(
      padding: padding ?? const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardLight,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: child,
    );
  }

  // ── Section label ─────────────────────────────────────────
  Widget _sectionLabel(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(
          text.toUpperCase(),
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: AppColors.textSecondaryLight,
            letterSpacing: 0.6,
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final service = ref.read(analyticsServiceProvider);

    return Scaffold(
      backgroundColor: AppColors.surfaceLight,
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: AppColors.primaryDeep,
                strokeWidth: 2.5,
              ),
            )
          : RefreshIndicator(
              color: AppColors.primaryDeep,
              onRefresh: _loadData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_data.isEmpty)
                      _buildEmptyState()
                    else ...[
                      _buildScoreCard(service),
                      const SizedBox(height: 20),
                      _sectionLabel('Overview'),
                      _buildMetricRow(service),
                      const SizedBox(height: 24),
                      _sectionLabel('Posture Distribution'),
                      _buildPieCard(service),
                      const SizedBox(height: 24),
                      _sectionLabel(
                        _selectedTimeRange == 0
                            ? 'Today — Hourly Score'
                            : _selectedTimeRange == 1
                                ? 'This Week — Daily Score'
                                : 'This Month — Daily Score',
                      ),
                      _buildLineCard(service),
                      const SizedBox(height: 24),
                      _buildProblematicCard(service),
                      const SizedBox(height: 12),
                      _buildExportButton(service),
                    ],
                  ],
                ),
              ),
            ),
    );
  }

  // ── Score hero card ──────────────────────────────────────
  Widget _buildScoreCard(AnalyticsService service) {
    final score = service.calculatePostureScore(_data);
    final Color scoreColor;
    final String scoreLabel;
    if (score >= 70) {
      scoreColor = AppColors.success;
      scoreLabel = 'Good posture';
    } else if (score >= 40) {
      scoreColor = const Color(0xFFF5A623);
      scoreLabel = 'Needs attention';
    } else {
      scoreColor = AppColors.danger;
      scoreLabel = 'Poor posture';
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primaryDeep, AppColors.primaryMid],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryDeep.withValues(alpha: 0.28),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 88,
            height: 88,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 88,
                  height: 88,
                  child: CircularProgressIndicator(
                    value: score / 100,
                    strokeWidth: 6,
                    backgroundColor: Colors.white.withValues(alpha: 0.20),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Colors.white.withValues(alpha: 0.90),
                    ),
                    strokeCap: StrokeCap.round,
                  ),
                ),
                Text(
                  '$score%',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    scoreLabel,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Posture Score',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${_data.length} readings analysed',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.65),
                  ),
                ),
              ],
            ),
          ),
          PopupMenuButton<int>(
            initialValue: _selectedTimeRange,
            onSelected: (value) {
              setState(() => _selectedTimeRange = value);
              _loadData();
            },
            color: Colors.white,
            itemBuilder: (context) => const [
              PopupMenuItem(value: 0, child: Text('Today')),
              PopupMenuItem(value: 1, child: Text('This Week')),
              PopupMenuItem(value: 2, child: Text('This Month')),
            ],
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _selectedTimeRange == 0
                        ? 'Today'
                        : _selectedTimeRange == 1
                            ? 'Week'
                            : 'Month',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Metric row ────────────────────────────────────────────
  Widget _buildMetricRow(AnalyticsService service) {
    final uprightCount = _data.where((d) => d.postureLabel == 'upright').length;
    final uprightMinutes = uprightCount * 2;
    final badCount = _data.where((d) => d.postureLabel != 'upright').length;

    return Row(
      children: [
        Expanded(
          child: _buildMetricTile(
            icon: Icons.check_circle_outline_rounded,
            value: '${uprightMinutes}m',
            label: 'Upright Time',
            iconBg: AppColors.success.withValues(alpha: 0.10),
            iconColor: AppColors.success,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildMetricTile(
            icon: Icons.data_usage_rounded,
            value: '${_data.length}',
            label: 'Total Readings',
            iconBg: AppColors.primaryDeep.withValues(alpha: 0.08),
            iconColor: AppColors.primaryDeep,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildMetricTile(
            icon: Icons.warning_amber_rounded,
            value: '$badCount',
            label: 'Poor Posture',
            iconBg: AppColors.danger.withValues(alpha: 0.09),
            iconColor: AppColors.danger,
          ),
        ),
      ],
    );
  }

  Widget _buildMetricTile({
    required IconData icon,
    required String value,
    required String label,
    required Color iconBg,
    required Color iconColor,
  }) {
    return _card(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimaryLight,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              color: AppColors.textSecondaryLight,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // ── Pie chart card ────────────────────────────────────────
  Widget _buildPieCard(AnalyticsService service) {
    final percentages = service.calculatePosturePercentages(_data);
    final counts = service.calculatePostureCounts(_data);
    final score = service.calculatePostureScore(_data);

    final validKeys = _postureKeys
        .where((k) => (percentages[k] ?? 0) > 0)
        .toList();

    return _card(
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                width: 150,
                height: 150,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    PieChart(
                      PieChartData(
                        sectionsSpace: 2,
                        centerSpaceRadius: 44,
                        startDegreeOffset: -90,
                        pieTouchData: PieTouchData(
                          touchCallback: (event, response) {
                            if (!event.isInterestedForInteractions ||
                                response?.touchedSection == null) return;
                            final i = response!.touchedSection!.touchedSectionIndex;
                            if (i >= 0 && i < validKeys.length) {
                              _pieResetTimer?.cancel();
                              setState(() => _touchedPieIndex = i);
                              _pieResetTimer = Timer(
                                const Duration(seconds: 3),
                                () {
                                  if (mounted) setState(() => _touchedPieIndex = null);
                                },
                              );
                            }
                          },
                        ),
                        sections: validKeys.asMap().entries.map((e) {
                          final i = e.key;
                          final key = e.value;
                          final pct = percentages[key] ?? 0;
                          final isTouched = _touchedPieIndex == i;
                          return PieChartSectionData(
                            color: _getDynamicPostureColor(key, percentages),
                            value: pct,
                            title: '',
                            radius: isTouched ? 52 : 42,
                          );
                        }).toList(),
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          (_touchedPieIndex != null && _touchedPieIndex! < validKeys.length)
                              ? '${(percentages[validKeys[_touchedPieIndex!]] ?? 0).toStringAsFixed(1)}%'
                              : '$score%',
                          style: TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w800,
                            color: (_touchedPieIndex != null && _touchedPieIndex! < validKeys.length)
                                ? _getDynamicPostureColor(validKeys[_touchedPieIndex!], percentages)
                                : AppColors.primaryDeep,
                            letterSpacing: -0.5,
                          ),
                        ),
                        Text(
                          (_touchedPieIndex != null && _touchedPieIndex! < validKeys.length)
                              ? _postureName(validKeys[_touchedPieIndex!])
                              : 'Score',
                          style: const TextStyle(
                            fontSize: 10,
                            color: AppColors.textSecondaryLight,
                            fontWeight: FontWeight.w500,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        if (_touchedPieIndex != null && _touchedPieIndex! < validKeys.length)
                          Text(
                            '${counts[validKeys[_touchedPieIndex!]] ?? 0} readings',
                            style: const TextStyle(
                              fontSize: 9,
                              color: AppColors.textSecondaryLight,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: _postureKeys.map((key) {
                    final name = _postureName(key);
                    final color = _getDynamicPostureColor(key, percentages);
                    final pct = percentages[key] ?? 0;
                    final hasData = pct > 0;

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 5),
                      child: Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: hasData ? color : AppColors.borderLight,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              name,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: hasData
                                    ? AppColors.textPrimaryLight
                                    : AppColors.textSecondaryLight,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            hasData ? '${pct.toStringAsFixed(1)}%' : '—',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: hasData ? color : AppColors.textSecondaryLight,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Line chart card ───────────────────────────────────────
  Widget _buildLineCard(AnalyticsService service) {
    final trend = _selectedTimeRange == 0
        ? service.calculateHourlyTrend(_data)
        : _selectedTimeRange == 1
            ? service.calculateWeeklyTrend(_data)
            : service.calculateMonthlyTrend(_data);

    final valid = trend.where((t) => t['score'] != -1).toList();

    if (valid.isEmpty) {
      return _card(
        child: const SizedBox(
          height: 100,
          child: Center(
            child: Text(
              'No data for this period',
              style: TextStyle(
                color: AppColors.textSecondaryLight,
                fontSize: 13,
              ),
            ),
          ),
        ),
      );
    }

    return _card(
      padding: const EdgeInsets.fromLTRB(8, 20, 16, 12),
      child: SizedBox(
        height: 190,
        child: LineChart(
          LineChartData(
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              getDrawingHorizontalLine: (v) => FlLine(
                color: AppColors.borderLight,
                strokeWidth: 1,
              ),
            ),
            titlesData: FlTitlesData(
              rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false)),
              topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false)),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 26,
                  interval: valid.length > 15
                      ? (valid.length / 6).ceilToDouble()
                      : 1,
                  getTitlesWidget: (value, meta) {
                    final i = value.toInt();
                    if (i < 0 || i >= valid.length) return const SizedBox();
                    return Padding(
                      padding: const EdgeInsets.only(top: 5),
                      child: Text(
                        valid[i]['label'] as String,
                        style: const TextStyle(
                          color: AppColors.textSecondaryLight,
                          fontSize: 9,
                        ),
                      ),
                    );
                  },
                ),
              ),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 34,
                  interval: 25,
                  getTitlesWidget: (v, meta) => Text(
                    '${v.toInt()}%',
                    style: const TextStyle(
                      color: AppColors.textSecondaryLight,
                      fontSize: 9,
                    ),
                  ),
                ),
              ),
            ),
            borderData: FlBorderData(show: false),
            minY: 0,
            maxY: 100,
            lineBarsData: [
              LineChartBarData(
                spots: valid.asMap().entries.map((e) => FlSpot(
                  e.key.toDouble(),
                  (e.value['score'] as int).toDouble(),
                )).toList(),
                isCurved: true,
                curveSmoothness: 0.35,
                color: AppColors.primaryDeep,
                barWidth: 2.5,
                isStrokeCapRound: true,
                dotData: FlDotData(
                  show: true,
                  getDotPainter: (spot, percent, bar, index) =>
                      FlDotCirclePainter(
                    radius: 3.5,
                    color: Colors.white,
                    strokeWidth: 2,
                    strokeColor: AppColors.primaryDeep,
                  ),
                ),
                belowBarData: BarAreaData(
                  show: true,
                  gradient: LinearGradient(
                    colors: [
                      AppColors.primaryDeep.withValues(alpha: 0.15),
                      AppColors.primaryDeep.withValues(alpha: 0.0),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Problematic posture card ─────────────────────────────
  Widget _buildProblematicCard(AnalyticsService service) {
    final problematic = service.getMostProblematicPosture(_data);
    if (problematic == 'none') return const SizedBox.shrink();

    final name = _postureName(problematic);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.red.shade100, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.priority_high_rounded, color: AppColors.danger, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'AREA OF FOCUS',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondaryLight,
                    letterSpacing: 0.6,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  name,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.danger,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 3),
                const Text(
                  'Correct this posture to improve your score',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondaryLight,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Export button ─────────────────────────────────────────
  Widget _buildExportButton(AnalyticsService service) {
    return GestureDetector(
      onTap: () => _generatePDF(service),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: const ShapeDecoration(
          color: AppColors.primaryDeep,
          shape: StadiumBorder(),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.picture_as_pdf_rounded, color: Colors.white, size: 18),
            SizedBox(width: 8),
            Text(
              'Export PDF Report',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Empty state ───────────────────────────────────────────
  Widget _buildEmptyState() {
    return _card(
      child: Column(
        children: [
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.primaryDeep.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.bar_chart_rounded,
              size: 36,
              color: AppColors.primaryDeep,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'No data yet',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimaryLight,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Wear your brace to start\nrecording posture data.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textSecondaryLight,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 20),
          GestureDetector(
            onTap: _loadData,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 10),
              decoration: const ShapeDecoration(
                color: AppColors.primaryDeep,
                shape: StadiumBorder(),
              ),
              child: const Text(
                'Refresh',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  // ── PDF generation ────────────────────────────────────────
  Future<void> _generatePDF(AnalyticsService service) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator(color: AppColors.primaryDeep)),
    );

    try {
      final user = ref.read(authStateProvider);
      if (user == null) throw Exception('User not logged in');

      final patientSnapshot = await FirebaseFirestore.instance
          .collection('patients')
          .where('userId', isEqualTo: user.userId)
          .limit(1)
          .get();

      if (patientSnapshot.docs.isEmpty) throw Exception('Patient record not found');

      final patientDoc = patientSnapshot.docs.first;
      final patient = patientDoc.data();

      final percentages = service.calculatePosturePercentages(_data);
      final counts = service.calculatePostureCounts(_data);
      final score = service.calculatePostureScore(_data);
      final problematic = service.getMostProblematicPosture(_data);
      final timeRangeLabel = _selectedTimeRange == 0
          ? 'Today'
          : _selectedTimeRange == 1
              ? 'Last 7 Days'
              : 'Last 30 Days';

      final pdf = pw.Document();
      pdf.addPage(pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (pw.Context ctx) => [
          pw.Container(
            padding: const pw.EdgeInsets.all(20),
            decoration: pw.BoxDecoration(
              color: PdfColors.blue800,
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(12)),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                  pw.Text('Smart Posture', style: pw.TextStyle(color: PdfColors.white, fontSize: 22, fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 4),
                  pw.Text('Posture Analysis Report', style: const pw.TextStyle(color: PdfColors.white, fontSize: 13)),
                ]),
                pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
                  pw.Text('Generated: ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}',
                      style: const pw.TextStyle(color: PdfColors.white, fontSize: 11)),
                  pw.SizedBox(height: 4),
                  pw.Text('Period: $timeRangeLabel', style: const pw.TextStyle(color: PdfColors.white, fontSize: 11)),
                ]),
              ],
            ),
          ),
          pw.SizedBox(height: 24),
          pw.Text('Patient Information', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 12),
          pw.Container(
            padding: const pw.EdgeInsets.all(16),
            decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey300), borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8))),
            child: pw.Table(children: [
              pw.TableRow(children: [
                pw.Text('Full Name', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.grey700)),
                pw.Text(patient['fullName'] ?? 'N/A'),
                pw.Text('Gender', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.grey700)),
                pw.Text(patient['gender'] ?? 'N/A'),
              ]),
              pw.TableRow(children: [
                pw.Text('Date of Birth', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.grey700)),
                pw.Text(patient['dateOfBirth'] ?? 'N/A'),
                pw.Text('Email', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.grey700)),
                pw.Text(patient['contactEmail'] ?? 'N/A'),
              ]),
            ]),
          ),
          pw.SizedBox(height: 24),
          pw.Text('Posture Score Summary', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 12),
          pw.Row(children: [
            pw.Container(
              width: 100, height: 100,
              decoration: pw.BoxDecoration(
                shape: pw.BoxShape.circle,
                color: score >= 70 ? PdfColors.green100 : score >= 40 ? PdfColors.orange100 : PdfColors.red100,
                border: pw.Border.all(color: score >= 70 ? PdfColors.green800 : score >= 40 ? PdfColors.orange800 : PdfColors.red800, width: 3),
              ),
              alignment: pw.Alignment.center,
              child: pw.Column(mainAxisAlignment: pw.MainAxisAlignment.center, children: [
                pw.Text('$score%', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold, color: score >= 70 ? PdfColors.green800 : score >= 40 ? PdfColors.orange800 : PdfColors.red800)),
                pw.Text('Score', style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey700)),
              ]),
            ),
            pw.SizedBox(width: 20),
            pw.Expanded(
              child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                pw.Text(score >= 70 ? 'Good posture habits detected.' : score >= 40 ? 'Moderate posture issues detected.' : 'Poor posture habits detected.',
                    style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 6),
                pw.Text('Total readings analyzed: ${_data.length}', style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700)),
                pw.SizedBox(height: 4),
                pw.Text('Most problematic: ${problematic == 'none' ? 'None' : problematic.replaceAll('_', ' ')}',
                    style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700)),
              ]),
            ),
          ]),
          pw.SizedBox(height: 24),
          pw.Text('Posture Breakdown', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 12),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey300),
            columnWidths: {0: const pw.FlexColumnWidth(3), 1: const pw.FlexColumnWidth(2), 2: const pw.FlexColumnWidth(2), 3: const pw.FlexColumnWidth(3)},
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.blue800),
                children: ['Posture', 'Readings', 'Percentage', 'Status'].map((h) =>
                    pw.Padding(padding: const pw.EdgeInsets.all(8),
                        child: pw.Text(h, style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold)))).toList(),
              ),
              ..._postureKeys.map((key) {
                final count = counts[key] ?? 0;
                final pct = percentages[key] ?? 0;
                final isGood = key == 'upright';
                final color = _getDynamicPostureColor(key, percentages);
                return pw.TableRow(
                  decoration: pw.BoxDecoration(color: isGood ? PdfColors.green50 : PdfColors.white),
                  children: [
                    pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text(_postureName(key))),
                    pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('$count')),
                    pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('${pct.toStringAsFixed(1)}%')),
                    pw.Padding(padding: const pw.EdgeInsets.all(8),
                        child: pw.Text(isGood ? 'Healthy' : 'Needs Improvement',
                            style: pw.TextStyle(color: isGood ? PdfColors.green800 : PdfColors.orange800, fontWeight: pw.FontWeight.bold))),
                  ],
                );
              }),
            ],
          ),
          pw.SizedBox(height: 24),
          pw.Divider(),
          pw.SizedBox(height: 8),
          pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
            pw.Text('Smart Posture App — Confidential Medical Report', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600)),
            pw.Text('Page 1', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600)),
          ]),
        ],
      ));

      final pdfBytes = await pdf.save();
      final directory = await getApplicationDocumentsDirectory();
      final fileName = 'posture_report_${DateTime.now().day}_${DateTime.now().month}_${DateTime.now().year}.pdf';
      await File('${directory.path}/$fileName').writeAsBytes(pdfBytes);

      final pdfBase64 = base64Encode(pdfBytes);
      final reportId = 'report_${DateTime.now().millisecondsSinceEpoch}';

      await FirebaseFirestore.instance.collection('reports').doc(reportId).set({
        'reportId': reportId,
        'patientId': patientDoc.id,
        'generatedAt': DateTime.now().toIso8601String(),
        'reportType': _selectedTimeRange == 0 ? 'daily' : _selectedTimeRange == 1 ? 'weekly' : 'monthly',
        'exportFormat': 'PDF',
        'postureScore': score,
        'totalReadings': _data.length,
        'mostProblematicPosture': problematic,
        'uprightPercent': percentages['upright']?.toStringAsFixed(1) ?? '0',
        'forwardBendingPercent': percentages['forward_bending']?.toStringAsFixed(1) ?? '0',
        'backwardBendingPercent': percentages['backward_bending']?.toStringAsFixed(1) ?? '0',
        'slouchingPercent': percentages['slouching']?.toStringAsFixed(1) ?? '0',
        'leftBendingPercent': percentages['left_bending']?.toStringAsFixed(1) ?? '0',
        'rightBendingPercent': percentages['right_bending']?.toStringAsFixed(1) ?? '0',
        'pdfBase64': pdfBase64,
        'period': timeRangeLabel,
      });

      if (mounted) Navigator.of(context).pop(); // close loading dialog

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Report saved successfully'),
            backgroundColor: AppColors.success,
            duration: Duration(seconds: 3),
          ),
        );
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => _PdfReportViewerScreen(
              pdfBytes: pdfBytes,
              title: timeRangeLabel,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) Navigator.of(context).pop();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save report: $e'),
            backgroundColor: AppColors.danger,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }
}
// ── Themed PDF report viewer with a real back button ──────────────────────
class _PdfReportViewerScreen extends StatelessWidget {
  final Uint8List pdfBytes;
  final String title;

  const _PdfReportViewerScreen({
    required this.pdfBytes,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceLight,
      appBar: AppBar(
        backgroundColor: AppColors.primaryDeep,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          '$title Report',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 16,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.ios_share_rounded, color: Colors.white),
            onPressed: () => Printing.sharePdf(bytes: pdfBytes, filename: 'posture_report.pdf'),
          ),
        ],
      ),
      body: PdfPreview(
        build: (format) => pdfBytes,
        useActions: false, // hide PdfPreview's own toolbar — we use our AppBar instead
        canChangeOrientation: false,
        canChangePageFormat: false,
        canDebug: false,
        pdfFileName: 'posture_report.pdf',
      ),
    );
  }
}