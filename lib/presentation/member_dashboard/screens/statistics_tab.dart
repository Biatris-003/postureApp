import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../data/datasources/analytics_service_mock.dart';
import '../../../domain/entities/posture_data.dart';

class StatisticsTab extends ConsumerStatefulWidget {
  const StatisticsTab({Key? key}) : super(key: key);

  @override
  ConsumerState<StatisticsTab> createState() => _StatisticsTabState();
}

class _StatisticsTabState extends ConsumerState<StatisticsTab> {
  int _selectedTimeRange = 0; // 0=Day, 1=Week, 2=Month

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<PostureData>>(
      future: ref.read(analyticsServiceProvider).getDailyHistory(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        
        final data = snapshot.data!;
        int upright = data.where((d) => d.postureClass == 'Upright').length;
        int bad = data.length - upright;
        
        // Mock calculations for summary cards
        double postureScore = (upright / data.length) * 100;

        return Scaffold(
          backgroundColor: Colors.grey[50],
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            title: const Text('Analytics', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
            actions: [
              IconButton(icon: const Icon(Icons.picture_as_pdf, color: Colors.blue), onPressed: () {}),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildTimeRangeSelector(),
                const SizedBox(height: 24),
                _buildSummaryCards(postureScore.toInt()),
                const SizedBox(height: 32),
                const Text('Posture Trend', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                _buildLineChart(data),
                const SizedBox(height: 32),
                const Text('Daily Overview', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                _buildPieChart(upright, bad),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTimeRangeSelector() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          _buildTimeTab('Day', 0),
          _buildTimeTab('Week', 1),
          _buildTimeTab('Month', 2),
        ],
      ),
    );
  }

  Widget _buildTimeTab(String text, int index) {
    final isSelected = _selectedTimeRange == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedTimeRange = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? Colors.blue.shade600 : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            boxShadow: isSelected ? [BoxShadow(color: Colors.blue.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))] : null,
          ),
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isSelected ? Colors.white : Colors.grey.shade600,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryCards(int score) {
    return Row(
      children: [
        Expanded(
          child: _buildMetricCard(
             title: 'Posture Score',
             value: '$score%',
             icon: Icons.score,
             color: Colors.blue,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildMetricCard(
             title: 'Upright Time',
             value: '4h 12m',
             icon: Icons.timer,
             color: Colors.green,
          ),
        ),
      ],
    );
  }

  Widget _buildMetricCard({required String title, required String value, required IconData icon, required MaterialColor color}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 15, offset: const Offset(0, 5))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 12),
          Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: -0.5)),
          const SizedBox(height: 4),
          Text(title, style: TextStyle(color: Colors.grey.shade600, fontSize: 13, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildLineChart(List<PostureData> data) {
    return Container(
      height: 250,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 15, offset: const Offset(0, 5))],
      ),
      child: LineChart(
        LineChartData(
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: 1,
            getDrawingHorizontalLine: (value) => FlLine(color: Colors.grey.shade200, strokeWidth: 1),
          ),
          titlesData: FlTitlesData(
            show: true,
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 30,
                interval: 5,
                getTitlesWidget: (value, meta) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text('${value.toInt()}h', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                  );
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: 1,
                reservedSize: 42,
                getTitlesWidget: (value, meta) {
                  return Text(value == 1 ? 'Good' : 'Bad', style: const TextStyle(color: Colors.grey, fontSize: 12));
                },
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
          minY: -0.2,
          maxY: 1.2,
          lineBarsData: [
            LineChartBarData(
              spots: data.asMap().entries.map((e) {
                 return FlSpot(e.key.toDouble(), e.value.postureClass == 'Upright' ? 1 : 0);
              }).toList(),
              isCurved: true,
              curveSmoothness: 0.3,
              color: Colors.blue.shade600,
              barWidth: 4,
              isStrokeCapRound: true,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  colors: [Colors.blue.withOpacity(0.4), Colors.transparent],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPieChart(int upright, int bad) {
    return Container(
      height: 250,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 15, offset: const Offset(0, 5))],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          PieChart(
            PieChartData(
              sectionsSpace: 4,
              centerSpaceRadius: 60,
              sections: [
                PieChartSectionData(
                  color: Colors.green.shade400,
                  value: upright.toDouble(),
                  title: 'Good',
                  radius: 30,
                  titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                  titlePositionPercentageOffset: 0.5,
                ),
                PieChartSectionData(
                  color: Colors.red.shade400,
                  value: bad.toDouble(),
                  title: 'Bad',
                  radius: 25,
                  titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                  titlePositionPercentageOffset: 0.5,
                ),
              ],
            ),
          ),
          const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Total', style: TextStyle(color: Colors.grey, fontSize: 14)),
              Text('24h', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            ],
          )
        ],
      ),
    );
  }
}
