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

// Provider for analytics service
final analyticsServiceProvider = Provider((ref) => AnalyticsService());

// Hardcoded for now, will come from auth later
const String currentPatientId = 'p001';

class StatisticsTab extends ConsumerStatefulWidget {
  const StatisticsTab({Key? key}) : super(key: key);

  @override
  ConsumerState<StatisticsTab> createState() => _StatisticsTabState();
}

class _StatisticsTabState extends ConsumerState<StatisticsTab> {
  int _selectedTimeRange = 0; // 0=Day, 1=Week, 2=Month
  List<PostureClassification> _data = [];
  bool _isLoading = true;
  int? _touchedPieIndex; // ← ADD THIS

  // Colors for each posture
  final Map<String, Color> postureColors = {
    'upright': Colors.green,
    'forward_bending': Colors.orange,
    'backward_bending': Colors.blue,
    'slouching': Colors.red,
    'left_bending': Colors.purple,
    'right_bending': Colors.pink,
  };

  // Display names for each posture
  final Map<String, String> postureNames = {
    'upright': 'Upright',
    'forward_bending': 'Forward Bending',
    'backward_bending': 'Backward Bending',
    'slouching': 'Slouching',
    'left_bending': 'Left Bending',
    'right_bending': 'Right Bending',
  };

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final service = ref.read(analyticsServiceProvider);

    try {
      List<PostureClassification> data;
      if (_selectedTimeRange == 0) {
        data = await service.getClassificationsByDays(currentPatientId, 1);
      } else if (_selectedTimeRange == 1) {
        data = await service.getClassificationsByDays(currentPatientId, 7);
      } else {
        data = await service.getClassificationsByDays(currentPatientId, 30);
      }
      setState(() {
        _data = data;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _data = [];
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final service = ref.read(analyticsServiceProvider);

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Analytics',
            style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf, color: Colors.blue),
            onPressed: _data.isEmpty
                ? null
                : () => _generatePDF(ref.read(analyticsServiceProvider)),
          ),
        ],
      ),
body: Builder(
  builder: (context) {
    final service = ref.read(analyticsServiceProvider);
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_data.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.bar_chart, size: 48, color: Colors.grey.shade300),
            const SizedBox(height: 8),
            Text('No data available',
                style: TextStyle(color: Colors.grey.shade500)),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _loadData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildTimeRangeSelector(),
            const SizedBox(height: 24),
            _buildSummaryCards(service),
            const SizedBox(height: 32),
            const Text('Posture Distribution',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            _buildPieChart(service),
            const SizedBox(height: 32),
            Text(
              _selectedTimeRange == 0
                  ? 'Today — Posture by Hour'
                  : _selectedTimeRange == 1
                      ? 'This Week — Daily Score'
                      : 'This Month — Daily Score',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildLineChart(service),
            const SizedBox(height: 32),
            _buildMostProblematicCard(service),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  },
    ),
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
          _buildTimeTab('Today', 0),
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
        onTap: () {
          setState(() => _selectedTimeRange = index);
          _loadData();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? Colors.blue.shade600 : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
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

  Widget _buildSummaryCards(AnalyticsService service) {
    final score = service.calculatePostureScore(_data);
    final uprightCount = _data.where((d) => d.postureLabel == 'upright').length;
    final uprightMinutes = uprightCount * 2; // each reading ≈ 2 minutes

    return Row(
      children: [
        Expanded(
          child: _buildMetricCard(
            title: 'Upright Score',
            value: '$score%',
            icon: Icons.score,
            color: score >= 70 ? Colors.green : score >= 40 ? Colors.orange : Colors.red,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildMetricCard(
            title: 'Upright Time',
            value: '${uprightMinutes}m',
            icon: Icons.timer,
            color: Colors.blue,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildMetricCard(
            title: 'Total Readings',
            value: '${_data.length}',
            icon: Icons.data_usage,
            color: Colors.purple,
          ),
        ),
      ],
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 15)
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(value,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(title,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 11)),
        ],
      ),
    );
  }

// Widget _buildPieChart(AnalyticsService service) {
//   final percentages = service.calculatePosturePercentages(_data);
//   final counts = service.calculatePostureCounts(_data);
//   int? _touchedIndex;

//   final postureConfig = [
//     {'key': 'upright',          'name': 'Upright',          'color': const Color(0xFF4CAF50)},
//     {'key': 'forward_bending',  'name': 'Forward Bending',  'color': const Color(0xFFFF9800)},
//     {'key': 'backward_bending', 'name': 'Backward Bending', 'color': const Color(0xFF2196F3)},
//     {'key': 'slouching',        'name': 'Slouching',        'color': const Color(0xFFF44336)},
//     {'key': 'left_bending',     'name': 'Left Bending',     'color': const Color(0xFF9C27B0)},
//     {'key': 'right_bending',    'name': 'Right Bending',    'color': const Color(0xFF00BCD4)},
//   ];

//   return StatefulBuilder(
//     builder: (context, setLocalState) {
//       return Container(
//         padding: const EdgeInsets.all(20),
//         decoration: BoxDecoration(
//           color: Colors.white,
//           borderRadius: BorderRadius.circular(24),
//           boxShadow: [BoxShadow(
//             color: Colors.black.withOpacity(0.06),
//             blurRadius: 20,
//             offset: const Offset(0, 4),
//           )],
//         ),
//         child: Column(
//           children: [
//             // Pie chart
//             SizedBox(
//               height: 260,
//               child: Stack(
//                 alignment: Alignment.center,
//                 children: [
//                   PieChart(
//                     PieChartData(
//                       sectionsSpace: 3,
//                       centerSpaceRadius: 70,
//                       startDegreeOffset: -90,
//                       pieTouchData: PieTouchData(
//                         touchCallback: (event, response) {
//                           setLocalState(() {
//                             if (response == null || response.touchedSection == null) {
//                               _touchedIndex = null;
//                             } else {
//                               _touchedIndex = response.touchedSection!.touchedSectionIndex;
//                             }
//                           });
//                         },
//                       ),
//                       sections: () {
//                         final validPostures = postureConfig
//                             .where((p) => (percentages[p['key']] ?? 0) > 0)
//                             .toList();
//                         return validPostures.asMap().entries.map((entry) {
//                           final index = entry.key;
//                           final p = entry.value;
//                           final pct = percentages[p['key'] as String] ?? 0;
//                           final isTouched = _touchedIndex == index;
//                           return PieChartSectionData(
//                             color: p['color'] as Color,
//                             value: pct,
//                             title: '',
//                             radius: isTouched ? 58 : 48,
//                             badgeWidget: isTouched
//                                 ? Container(
//                                     padding: const EdgeInsets.symmetric(
//                                         horizontal: 8, vertical: 4),
//                                     decoration: BoxDecoration(
//                                       color: p['color'] as Color,
//                                       borderRadius: BorderRadius.circular(8),
//                                       boxShadow: [BoxShadow(
//                                         color: (p['color'] as Color).withOpacity(0.4),
//                                         blurRadius: 8,
//                                       )],
//                                     ),
//                                     child: Text(
//                                       '${pct.toStringAsFixed(1)}%',
//                                       style: const TextStyle(
//                                         color: Colors.white,
//                                         fontSize: 11,
//                                         fontWeight: FontWeight.bold,
//                                       ),
//                                     ),
//                                   )
//                                 : null,
//                             badgePositionPercentageOffset: 1.3,
//                           );
//                         }).toList();
//                       }(),
//                     ),
//                   ),
//                   // Center — shows score or touched posture info
//                   _touchedIndex != null
//                       ? Builder(builder: (context) {
//                           final validPostures = postureConfig
//                               .where((p) => (percentages[p['key']] ?? 0) > 0)
//                               .toList();
//                           if (_touchedIndex! >= validPostures.length) {
//                             return const SizedBox();
//                           }
//                           final p = validPostures[_touchedIndex!];
//                           final pct = percentages[p['key'] as String] ?? 0;
//                           final count = counts[p['key'] as String] ?? 0;
//                           return Column(
//                             mainAxisSize: MainAxisSize.min,
//                             children: [
//                               Text(
//                                 '${pct.toStringAsFixed(1)}%',
//                                 style: TextStyle(
//                                   fontSize: 26,
//                                   fontWeight: FontWeight.bold,
//                                   color: p['color'] as Color,
//                                 ),
//                               ),
//                               Text(
//                                 '$count readings',
//                                 style: TextStyle(
//                                   fontSize: 11,
//                                   color: Colors.grey.shade500,
//                                 ),
//                               ),
//                               const SizedBox(height: 2),
//                               Text(
//                                 p['name'] as String,
//                                 textAlign: TextAlign.center,
//                                 style: TextStyle(
//                                   fontSize: 10,
//                                   color: Colors.grey.shade600,
//                                   fontWeight: FontWeight.w600,
//                                 ),
//                               ),
//                             ],
//                           );
//                         })
//                       : Column(
//                           mainAxisSize: MainAxisSize.min,
//                           children: [
//                             Text(
//                               '${service.calculatePostureScore(_data)}%',
//                               style: const TextStyle(
//                                 fontSize: 30,
//                                 fontWeight: FontWeight.bold,
//                                 color: Color(0xFF4CAF50),
//                               ),
//                             ),
//                             Text(
//                               'Posture\nScore',
//                               textAlign: TextAlign.center,
//                               style: TextStyle(
//                                 fontSize: 11,
//                                 color: Colors.grey.shade500,
//                                 height: 1.4,
//                               ),
//                             ),
//                           ],
//                         ),
//                 ],
//               ),
//             ),

//             const SizedBox(height: 16),
//             const Divider(height: 1, color: Color(0xFFEEEEEE)),
//             const SizedBox(height: 16),

//             // Legend — 2 column grid, each posture as a pill
//             GridView.builder(
//               shrinkWrap: true,
//               physics: const NeverScrollableScrollPhysics(),
//               gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
//                 crossAxisCount: 2,
//                 childAspectRatio: 3.8,
//                 crossAxisSpacing: 8,
//                 mainAxisSpacing: 8,
//               ),
//               itemCount: postureConfig.length,
//               itemBuilder: (context, index) {
//                 final p = postureConfig[index];
//                 final key = p['key'] as String;
//                 final pct = percentages[key] ?? 0;
//                 final count = counts[key] ?? 0;
//                 final color = p['color'] as Color;
//                 return Container(
//                   padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
//                   decoration: BoxDecoration(
//                     color: color.withOpacity(0.08),
//                     borderRadius: BorderRadius.circular(10),
//                     border: Border.all(color: color.withOpacity(0.25)),
//                   ),
//                   child: Row(
//                     children: [
//                       Container(
//                         width: 10,
//                         height: 10,
//                         decoration: BoxDecoration(
//                           color: color,
//                           shape: BoxShape.circle,
//                         ),
//                       ),
//                       const SizedBox(width: 6),
//                       Expanded(
//                         child: Column(
//                           crossAxisAlignment: CrossAxisAlignment.start,
//                           mainAxisAlignment: MainAxisAlignment.center,
//                           children: [
//                             Text(
//                               p['name'] as String,
//                               style: const TextStyle(
//                                 fontSize: 10,
//                                 fontWeight: FontWeight.w600,
//                               ),
//                               overflow: TextOverflow.ellipsis,
//                             ),
//                             Text(
//                               '$count · ${pct.toStringAsFixed(1)}%',
//                               style: TextStyle(
//                                 fontSize: 10,
//                                 color: Colors.grey.shade500,
//                               ),
//                             ),
//                           ],
//                         ),
//                       ),
//                     ],
//                   ),
//                 );
//               },
//             ),
//           ],
//         ),
//       );
//     },
//   );
// }
Widget _buildPieChart(AnalyticsService service) {
  final percentages = service.calculatePosturePercentages(_data);
  final counts = service.calculatePostureCounts(_data);
  
  // Timer for auto-reset
  Timer? _resetTimer;
  
  final postureConfig = [
    {'key': 'upright',          'name': 'Upright',          'color': const Color(0xFF5B8FF9)},
    {'key': 'forward_bending',  'name': 'Forward Bending',  'color': const Color(0xFF61DDAA)},
    {'key': 'backward_bending', 'name': 'Backward Bending', 'color': const Color(0xFFFFB44C)},
    {'key': 'slouching',        'name': 'Slouching',        'color': const Color(0xFFFF6B6B)},
    {'key': 'left_bending',     'name': 'Left Bending',     'color': const Color(0xFFB37FEB)},
    {'key': 'right_bending',    'name': 'Right Bending',    'color': const Color(0xFF54C0C0)},
  ];
  
  // Order for bottom legend as requested
  final legendOrder = [
    'upright',
    'forward_bending', 
    'backward_bending',
    'slouching',
    'left_bending',
    'right_bending'
  ];

  final validPostures = postureConfig
      .where((p) => (percentages[p['key'] as String] ?? 0) > 0)
      .toList();

  return StatefulBuilder(
    builder: (context, setLocalState) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 20,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Column(
          children: [
            // ================= PIE CHART =================
            SizedBox(
              height: 200,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  PieChart(
                    PieChartData(
                      sectionsSpace: 3,
                      centerSpaceRadius: 52,
                      startDegreeOffset: -90,
                      pieTouchData: PieTouchData(
                        touchCallback: (event, response) {
                          setLocalState(() {
                            // Cancel any existing timer
                            _resetTimer?.cancel();
                            
                            // If nothing valid is touched → do nothing
                            if (response == null ||
                                response.touchedSection == null ||
                                !event.isInterestedForInteractions) {
                              return;
                            }

                            final index = response.touchedSection!.touchedSectionIndex;
                            
                            // Ignore invalid index
                            if (index < 0 || index >= validPostures.length) {
                              return;
                            }

                            // Set the touched index
                            _touchedPieIndex = index;
                            
                            // Start timer to reset after 3 seconds
                            _resetTimer = Timer(const Duration(seconds: 3), () {
                              if (mounted) {
                                setLocalState(() {
                                  _touchedPieIndex = null;
                                });
                              }
                            });
                          });
                        },
                      ),
                      sections: validPostures.asMap().entries.map((entry) {
                        final i = entry.key;
                        final p = entry.value;
                        final pct = percentages[p['key'] as String] ?? 0;
                        final isTouched = _touchedPieIndex == i;
                        
                        return PieChartSectionData(
                          color: p['color'] as Color,
                          value: pct,
                          title: '',
                          radius: isTouched ? 58 : 48,
                          badgeWidget: isTouched
                              ? Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: p['color'] as Color,
                                    borderRadius: BorderRadius.circular(8),
                                    boxShadow: [
                                      BoxShadow(
                                        color: (p['color'] as Color).withOpacity(0.4),
                                        blurRadius: 8,
                                      )
                                    ],
                                  ),
                                  child: Text(
                                    '${pct.toStringAsFixed(1)}%',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                )
                              : null,
                          badgePositionPercentageOffset: 1.3,
                        );
                      }).toList(),
                    ),
                  ),
                  
                  // ================= CENTER TEXT =================
                  (_touchedPieIndex != null && _touchedPieIndex! < validPostures.length)
                      ? Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '${(percentages[validPostures[_touchedPieIndex!]['key'] as String] ?? 0).toStringAsFixed(1)}%',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: validPostures[_touchedPieIndex!]['color'] as Color,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              validPostures[_touchedPieIndex!]['name'] as String,
                              style: TextStyle(
                                fontSize: 10,
                                color: const Color.fromARGB(255, 0, 0, 0),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${counts[validPostures[_touchedPieIndex!]['key'] as String] ?? 0} readings',
                              style: TextStyle(
                                fontSize: 9,
                                color: const Color.fromARGB(255, 2, 2, 2),
                              ),
                            ),
                          ],
                        )
                      : Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '${service.calculatePostureScore(_data)}%',
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF5B8FF9),
                              ),
                            ),
                            Text(
                              'Score',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade500,
                              ),
                            ),
                          ],
                        ),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            const Divider(height: 1, color: Color(0xFFEEEEEE)),
            const SizedBox(height: 16),
            
            // ================= LEGEND AT BOTTOM (3x2 GRID LAYOUT) =================
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3, // Three items per row
                childAspectRatio: 2.5, // Adjust this to control height
                crossAxisSpacing: 1,
                mainAxisSpacing: 2,
              ),
              itemCount: legendOrder.length, // Always 6 items
              itemBuilder: (context, index) {
                final key = legendOrder[index];
                final posture = postureConfig.firstWhere((p) => p['key'] == key);
                final hasData = (percentages[key] ?? 0) > 0;
                
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: hasData ? posture['color'] as Color : Colors.grey.shade300,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        posture['name'] as String,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          color: hasData ? Colors.black87 : Colors.grey.shade400,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      );
    },
  );
}

  Widget _buildLineChart(AnalyticsService service) {
    // Pick correct trend based on selected time range
    List<Map<String, dynamic>> trend;
    if (_selectedTimeRange == 0) {
      trend = service.calculateHourlyTrend(_data);
    } else if (_selectedTimeRange == 1) {
      trend = service.calculateWeeklyTrend(_data);
    } else {
      trend = service.calculateMonthlyTrend(_data);
    }

    // Only show points that have data (score != -1)
    final validTrend = trend.where((t) => t['score'] != -1).toList();

    if (validTrend.isEmpty) {
      return Container(
        height: 200,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 15,
          )],
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.bar_chart, size: 40, color: Colors.grey.shade300),
              const SizedBox(height: 8),
              Text(
                'No data for this period',
                style: TextStyle(color: Colors.grey.shade500),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      height: 250,
      padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(
          color: Colors.black.withOpacity(0.04),
          blurRadius: 15,
        )],
      ),
      child: LineChart(
        LineChartData(
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (value) =>
                FlLine(color: Colors.grey.shade100, strokeWidth: 1),
          ),
          titlesData: FlTitlesData(
            rightTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 30,
                // Show fewer labels to avoid crowding
                interval: validTrend.length > 15
                    ? (validTrend.length / 6).ceilToDouble()
                    : 1,
                getTitlesWidget: (value, meta) {
                  final index = value.toInt();
                  if (index < 0 || index >= validTrend.length) {
                    return const Text('');
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      validTrend[index]['label'],
                      style: TextStyle(
                          color: Colors.grey.shade500, fontSize: 10),
                    ),
                  );
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 36,
                interval: 25,
                getTitlesWidget: (value, meta) => Text(
                  '${value.toInt()}%',
                  style: TextStyle(
                      color: Colors.grey.shade500, fontSize: 10),
                ),
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
          minY: 0,
          maxY: 100,
          lineBarsData: [
            LineChartBarData(
              spots: validTrend.asMap().entries
                  .map((e) => FlSpot(
                      e.key.toDouble(),
                      (e.value['score'] as int).toDouble()))
                  .toList(),
              isCurved: true,
              curveSmoothness: 0.4,
              color: const Color(0xFF5B8FF9),
              barWidth: 3,
              isStrokeCapRound: true,
              dotData: FlDotData(
                show: true,
                getDotPainter: (spot, percent, bar, index) =>
                    FlDotCirclePainter(
                  radius: 4,
                  color: Colors.white,
                  strokeWidth: 2.5,
                  strokeColor: const Color(0xFF5B8FF9),
                ),
              ),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF5B8FF9).withOpacity(0.25),
                    const Color(0xFF5B8FF9).withOpacity(0.0),
                  ],
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

  Widget _buildMostProblematicCard(AnalyticsService service) {
    final problematic = service.getMostProblematicPosture(_data);
    if (problematic == 'none') return const SizedBox();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [const Color(0xFFFEF2F2), const Color(0xFFFEE2E2)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFFECACA), width: 1),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFEF4444).withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.priority_high_rounded, color: Color(0xFFEF4444), size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Area of Focus',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: Color(0xFF7F1D1D),
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  postureNames[problematic] ?? problematic,
                  style: const TextStyle(
                    color: Color(0xFF991B1B),
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Improve your score by correcting this posture',
                  style: TextStyle(color: const Color(0xFF7F1D1D).withOpacity(0.8), fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }


  Future<void> _generatePDF(AnalyticsService service) async {
    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    try {
      // Fetch patient info
      final patientDoc = await FirebaseFirestore.instance
          .collection('patients')
          .doc(currentPatientId)
          .get();
      final patient = patientDoc.data()!;

      final percentages = service.calculatePosturePercentages(_data);
      final counts = service.calculatePostureCounts(_data);
      final score = service.calculatePostureScore(_data);
      final problematic = service.getMostProblematicPosture(_data);

      final timeRangeLabel = _selectedTimeRange == 0
          ? 'Today'
          : _selectedTimeRange == 1
              ? 'Last 7 Days'
              : 'Last 30 Days';

      final postureConfig = [
        {'key': 'upright',          'name': 'Upright'},
        {'key': 'forward_bending',  'name': 'Forward Bending'},
        {'key': 'backward_bending', 'name': 'Backward Bending'},
        {'key': 'slouching',        'name': 'Slouching'},
        {'key': 'left_bending',     'name': 'Left Bending'},
        {'key': 'right_bending',    'name': 'Right Bending'},
      ];

      // ── Build PDF ───────────────────────────────────────────
      final pdf = pw.Document();

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(40),
          build: (pw.Context context) => [

            // Header
            pw.Container(
              padding: const pw.EdgeInsets.all(20),
              decoration: pw.BoxDecoration(
                color: PdfColors.blue800,
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(12)),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('Smart Posture',
                          style: pw.TextStyle(
                              color: PdfColors.white,
                              fontSize: 22,
                              fontWeight: pw.FontWeight.bold)),
                      pw.SizedBox(height: 4),
                      pw.Text('Posture Analysis Report',
                          style: const pw.TextStyle(
                              color: PdfColors.white, fontSize: 13)),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                          'Generated: ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}',
                          style: const pw.TextStyle(
                              color: PdfColors.white, fontSize: 11)),
                      pw.SizedBox(height: 4),
                      pw.Text('Period: $timeRangeLabel',
                          style: const pw.TextStyle(
                              color: PdfColors.white, fontSize: 11)),
                    ],
                  ),
                ],
              ),
            ),

            pw.SizedBox(height: 24),

            // Patient info
            pw.Text('Patient Information',
                style: pw.TextStyle(
                    fontSize: 16, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 12),
            pw.Container(
              padding: const pw.EdgeInsets.all(16),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey300),
                borderRadius:
                    const pw.BorderRadius.all(pw.Radius.circular(8)),
              ),
              child: pw.Table(
                children: [
                  pw.TableRow(children: [
                    pw.Text('Full Name',
                        style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.grey700)),
                    pw.Text(patient['fullName'] ?? 'N/A'),
                    pw.Text('Gender',
                        style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.grey700)),
                    pw.Text(patient['gender'] ?? 'N/A'),
                  ]),
                  pw.TableRow(children: [
                    pw.Text('Date of Birth',
                        style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.grey700)),
                    pw.Text(patient['dateOfBirth'] ?? 'N/A'),
                    pw.Text('Email',
                        style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.grey700)),
                    pw.Text(patient['contactEmail'] ?? 'N/A'),
                  ]),
                ],
              ),
            ),

            pw.SizedBox(height: 24),

            // Score summary
            pw.Text('Posture Score Summary',
                style: pw.TextStyle(
                    fontSize: 16, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 12),
            pw.Row(
              children: [
                pw.Container(
                  width: 100,
                  height: 100,
                  decoration: pw.BoxDecoration(
                    shape: pw.BoxShape.circle,
                    color: score >= 70
                        ? PdfColors.green100
                        : score >= 40
                            ? PdfColors.orange100
                            : PdfColors.red100,
                    border: pw.Border.all(
                      color: score >= 70
                          ? PdfColors.green800
                          : score >= 40
                              ? PdfColors.orange800
                              : PdfColors.red800,
                      width: 3,
                    ),
                  ),
                  alignment: pw.Alignment.center,
                  child: pw.Column(
                    mainAxisAlignment: pw.MainAxisAlignment.center,
                    children: [
                      pw.Text('$score%',
                          style: pw.TextStyle(
                            fontSize: 24,
                            fontWeight: pw.FontWeight.bold,
                            color: score >= 70
                                ? PdfColors.green800
                                : score >= 40
                                    ? PdfColors.orange800
                                    : PdfColors.red800,
                          )),
                      pw.Text('Score',
                          style: const pw.TextStyle(
                              fontSize: 11, color: PdfColors.grey700)),
                    ],
                  ),
                ),
                pw.SizedBox(width: 20),
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        score >= 70
                            ? 'Good posture habits detected.'
                            : score >= 40
                                ? 'Moderate posture issues detected.'
                                : 'Poor posture habits detected.',
                        style: pw.TextStyle(
                            fontSize: 13, fontWeight: pw.FontWeight.bold),
                      ),
                      pw.SizedBox(height: 6),
                      pw.Text('Total readings analyzed: ${_data.length}',
                          style: const pw.TextStyle(
                              fontSize: 12, color: PdfColors.grey700)),
                      pw.SizedBox(height: 4),
                      pw.Text(
                          'Most problematic posture: ${problematic == 'none' ? 'None' : problematic.replaceAll('_', ' ')}',
                          style: const pw.TextStyle(
                              fontSize: 12, color: PdfColors.grey700)),
                    ],
                  ),
                ),
              ],
            ),

            pw.SizedBox(height: 24),

            // Posture breakdown table
            pw.Text('Posture Breakdown',
                style: pw.TextStyle(
                    fontSize: 16, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 12),
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300),
              columnWidths: {
                0: const pw.FlexColumnWidth(3),
                1: const pw.FlexColumnWidth(2),
                2: const pw.FlexColumnWidth(2),
                3: const pw.FlexColumnWidth(3),
              },
              children: [
                pw.TableRow(
                  decoration:
                      const pw.BoxDecoration(color: PdfColors.blue800),
                  children: [
                    pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text('Posture',
                            style: pw.TextStyle(
                                color: PdfColors.white,
                                fontWeight: pw.FontWeight.bold))),
                    pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text('Readings',
                            style: pw.TextStyle(
                                color: PdfColors.white,
                                fontWeight: pw.FontWeight.bold))),
                    pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text('Percentage',
                            style: pw.TextStyle(
                                color: PdfColors.white,
                                fontWeight: pw.FontWeight.bold))),
                    pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text('Status',
                            style: pw.TextStyle(
                                color: PdfColors.white,
                                fontWeight: pw.FontWeight.bold))),
                  ],
                ),
                ...postureConfig.map((p) {
                  final key = p['key']!;
                  final count = counts[key] ?? 0;
                  final pct = percentages[key] ?? 0;
                  final isGood = key == 'upright';
                  return pw.TableRow(
                    decoration: pw.BoxDecoration(
                        color: isGood ? PdfColors.green50 : PdfColors.white),
                    children: [
                      pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text(p['name']!)),
                      pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text('$count')),
                      pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text('${pct.toStringAsFixed(1)}%')),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text(
                          isGood ? 'Healthy' : 'Needs Improvement',
                          style: pw.TextStyle(
                            color: isGood
                                ? PdfColors.green800
                                : PdfColors.orange800,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  );
                }),
              ],
            ),

            pw.SizedBox(height: 24),
            pw.Divider(),
            pw.SizedBox(height: 8),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Smart Posture App — Confidential Medical Report',
                    style: const pw.TextStyle(
                        fontSize: 10, color: PdfColors.grey600)),
                pw.Text('Page 1',
                    style: const pw.TextStyle(
                        fontSize: 10, color: PdfColors.grey600)),
              ],
            ),
          ],
        ),
      );

      // ── Save PDF bytes ───────────────────────────────────────
      final pdfBytes = await pdf.save();

  // ── Save PDF to laptop/device downloads ─────────────────
  final directory = await getApplicationDocumentsDirectory();
  final fileName = 'posture_report_${DateTime.now().day}_${DateTime.now().month}_${DateTime.now().year}.pdf';
  final file = File('${directory.path}/$fileName');
  await file.writeAsBytes(pdfBytes);
  print('✅ PDF saved at: ${file.path}');
      // ── Upload to Firebase Storage ───────────────────────────
  // ── Convert PDF to base64 string ────────────────────────
  final pdfBase64 = base64Encode(pdfBytes);

  // ── Save to Firestore directly (no Storage needed) ──────
  final reportId = 'report_${DateTime.now().millisecondsSinceEpoch}';

  await FirebaseFirestore.instance.collection('reports').doc(reportId).set({
    'reportId': reportId,
    'patientId': currentPatientId,
    'generatedAt': DateTime.now().toIso8601String(),
    'reportType': _selectedTimeRange == 0
        ? 'daily'
        : _selectedTimeRange == 1
            ? 'weekly'
            : 'monthly',
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
    'pdfBase64': pdfBase64,   // ← PDF stored as base64 string
    'period': timeRangeLabel,
  });

  // ── Close loading dialog ─────────────────────────────────
  if (mounted) Navigator.of(context).pop();

  // ── Show PDF preview to user ─────────────────────────────
  await Printing.layoutPdf(onLayout: (format) async => pdfBytes);

  // ── Show success snackbar ────────────────────────────────
  if (mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('✅ Report saved to database successfully!'),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 3),
      ),
    );
  }

    } catch (e) {
      // Close loading dialog on error
      if (mounted) Navigator.of(context).pop();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Failed to save report: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }
}