import 'package:flutter/material.dart';
import 'package:flutter_test_application_1/models/detection_history_entry.dart';
import 'package:flutter_test_application_1/models/plant_model.dart';
import 'package:flutter_test_application_1/services/plant_service.dart';
import 'package:flutter_test_application_1/utils/export_utils.dart';
import 'package:flutter_test_application_1/views/widgets/detection_history_card.dart';
import 'package:flutter_test_application_1/views/widgets/detection_history_chart.dart';
import 'package:flutter_test_application_1/views/widgets/filter_chip_list.dart';

/// A screen that displays the user's detection history
class DetectionHistoryScreen extends StatefulWidget {
  const DetectionHistoryScreen({Key? key}) : super(key: key);

  @override
  _DetectionHistoryScreenState createState() => _DetectionHistoryScreenState();
}

class _DetectionHistoryScreenState extends State<DetectionHistoryScreen> {
  final PlantService _plantService = PlantService();

  // Filter state
  DateTime? _startDate;
  DateTime? _endDate;
  String? _selectedPlantType;
  String? _selectedDisease;

  // Keep track of all available plant types and diseases for filtering
  List<String> _availablePlantTypes = [];
  List<String> _availableDiseases = [];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Detection History'),
        actions: [
          IconButton(
            icon: const Icon(Icons.download),
            tooltip: 'Export Results',
            onPressed: _exportResults,
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter chips
          FilterChipList(
            onDateRangeSelected: (start, end) {
              setState(() {
                _startDate = start;
                _endDate = end;
              });
            },
            onPlantTypeSelected: (type) {
              setState(() {
                _selectedPlantType = type;
              });
            },
            onDiseaseSelected: (disease) {
              setState(() {
                _selectedDisease = disease;
              });
            },
            availablePlantTypes: _availablePlantTypes,
            availableDiseases: _availableDiseases,
          ),

          // Charts section
          DetectionHistoryChart(historyStream: _filteredStream),

          // History list
          Expanded(
            child: StreamBuilder<List<PlantModel>>(
              stream: _filteredStream,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final plantList = snapshot.data!;
                if (plantList.isEmpty) {
                  return const Center(
                    child: Text('No detection history available'),
                  );
                }

                // Convert to history entries
                final entries =
                    plantList
                        .map((plant) => DetectionHistoryEntry(plant))
                        .toList();

                // Update available filters
                _updateAvailableFilters(entries);

                return ListView.builder(
                  itemCount: entries.length,
                  itemBuilder: (context, index) {
                    return DetectionHistoryCard(entry: entries[index]);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// Updates the available plant types and diseases for filtering
  void _updateAvailableFilters(List<DetectionHistoryEntry> entries) {
    final plantTypes = <String>{};
    final diseases = <String>{};

    for (var entry in entries) {
      if (entry.plantType != 'Unknown') {
        plantTypes.add(entry.plantType);
      }

      if (entry.hasResults) {
        diseases.add(entry.diseaseName);
      }
    }

    // Only update state if filter options have changed
    if (plantTypes.length != _availablePlantTypes.length ||
        diseases.length != _availableDiseases.length) {
      setState(() {
        _availablePlantTypes = plantTypes.toList()..sort();
        _availableDiseases = diseases.toList()..sort();
      });
    }
  }

  /// Get filtered stream based on selections
  Stream<List<PlantModel>> get _filteredStream =>
      _plantService.userPlantsStream().map((plants) {
        return plants.where((plant) {
          // Apply date filtering
          if (_startDate != null || _endDate != null) {
            final createdAt = plant.createdAt;
            if (_startDate != null && createdAt.isBefore(_startDate!)) {
              return false;
            }
            if (_endDate != null) {
              // Include the entire end date (end of day)
              final endOfDay = DateTime(
                _endDate!.year,
                _endDate!.month,
                _endDate!.day,
                23,
                59,
                59,
              );
              if (createdAt.isAfter(endOfDay)) {
                return false;
              }
            }
          }

          // Convert to entry for easier filtering
          final entry = DetectionHistoryEntry(plant);

          // Apply plant type filter
          if (_selectedPlantType != null &&
              entry.plantType != _selectedPlantType) {
            return false;
          }

          // Apply disease filter
          if (_selectedDisease != null &&
              entry.diseaseName != _selectedDisease) {
            return false;
          }

          return true;
        }).toList();
      });

  /// Export filtered results to CSV
  Future<void> _exportResults() async {
    try {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      // Request permission
      final hasPermission = await ExportUtils.requestStoragePermission();
      if (!hasPermission) {
        Navigator.pop(context); // Dismiss loading
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Storage permission required for export'),
          ),
        );
        return;
      }

      // Get the latest data
      final plants = await _plantService.getUserPlants(limit: 100);
      final filtered =
          plants.where((plant) {
            // Similar filtering logic as _filteredStream
            final entry = DetectionHistoryEntry(plant);

            // Apply date filtering
            if (_startDate != null || _endDate != null) {
              final createdAt = plant.createdAt;
              if (_startDate != null && createdAt.isBefore(_startDate!)) {
                return false;
              }
              if (_endDate != null) {
                final endOfDay = DateTime(
                  _endDate!.year,
                  _endDate!.month,
                  _endDate!.day,
                  23,
                  59,
                  59,
                );
                if (createdAt.isAfter(endOfDay)) {
                  return false;
                }
              }
            }

            // Apply plant type filter
            if (_selectedPlantType != null &&
                entry.plantType != _selectedPlantType) {
              return false;
            }

            // Apply disease filter
            if (_selectedDisease != null &&
                entry.diseaseName != _selectedDisease) {
              return false;
            }

            return true;
          }).toList();

      // Convert to entries
      final entries = filtered.map((p) => DetectionHistoryEntry(p)).toList();

      // Dismiss loading
      Navigator.pop(context);

      if (entries.isEmpty) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('No data to export')));
        return;
      }

      // Export to CSV
      await ExportUtils.exportToCsv(entries);
    } catch (e) {
      // Dismiss loading if still showing
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Export failed: ${e.toString()}')));
    }
  }
}
