import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_test_application_1/models/detection_history_entry.dart';
import 'package:flutter_test_application_1/models/plant_model.dart';

/// A widget that displays charts for detection history
class DetectionHistoryChart extends StatelessWidget {
  /// Stream of plant models for generating charts
  final Stream<List<PlantModel>> historyStream;

  const DetectionHistoryChart({Key? key, required this.historyStream})
    : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Disease Distribution',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 180,
              child: StreamBuilder<List<PlantModel>>(
                stream: historyStream,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(child: Text('Error: ${snapshot.error}'));
                  }

                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return const Center(child: Text('No data available'));
                  }

                  final plantList = snapshot.data!;

                  // Convert to history entries
                  final entries =
                      plantList
                          .map((plant) => DetectionHistoryEntry(plant))
                          .where((entry) => entry.hasResults)
                          .toList();

                  if (entries.isEmpty) {
                    return const Center(child: Text('No completed analyses'));
                  }

                  // Create disease distribution data
                  final diseaseMap = <String, int>{};
                  for (var entry in entries) {
                    final disease = entry.diseaseName;
                    diseaseMap[disease] = (diseaseMap[disease] ?? 0) + 1;
                  }

                  // Prepare data for pie chart
                  final sections =
                      diseaseMap.entries.map((e) {
                        final disease = e.key;
                        final count = e.value;
                        final color = _getColorForDisease(disease);

                        return PieChartSectionData(
                          value: count.toDouble(),
                          title: '$disease\n$count',
                          titleStyle: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                          radius: 80,
                          color: color,
                        );
                      }).toList();

                  return Row(
                    children: [
                      // Pie chart
                      Expanded(
                        child: PieChart(
                          PieChartData(
                            sections: sections,
                            sectionsSpace: 2,
                            centerSpaceRadius: 0,
                            startDegreeOffset: 180,
                          ),
                        ),
                      ),

                      // Legend
                      if (diseaseMap.length > 3)
                        Expanded(
                          child: ListView(
                            shrinkWrap: true,
                            children:
                                diseaseMap.entries.map((e) {
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 4,
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 12,
                                          height: 12,
                                          decoration: BoxDecoration(
                                            color: _getColorForDisease(e.key),
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            e.key,
                                            style: const TextStyle(
                                              fontSize: 12,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        Text(
                                          '${e.value}',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Get a color for a disease name
  Color _getColorForDisease(String disease) {
    if (disease.toLowerCase().contains('healthy')) {
      return Colors.green.shade400;
    }

    // Generate a color based on the hash of the disease name
    final hash = disease.hashCode.abs();
    const colorList = [
      Colors.blue,
      Colors.red,
      Colors.orange,
      Colors.purple,
      Colors.teal,
      Colors.indigo,
      Colors.amber,
      Colors.pink,
    ];

    return colorList[hash % colorList.length];
  }
}
