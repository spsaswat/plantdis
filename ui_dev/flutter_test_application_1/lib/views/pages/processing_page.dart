import 'package:flutter/material.dart';
import 'package:flutter_test_application_1/models/plant_model.dart';
import 'package:flutter_test_application_1/services/plant_service.dart';
import 'package:flutter_test_application_1/views/widgets/appbar_widget.dart';
import 'package:flutter_test_application_1/views/widgets/card_widget.dart';
import 'package:flutter_test_application_1/utils/logger.dart';

import '../../services/local_guest_service.dart';

class ProcessingPage extends StatefulWidget {
  const ProcessingPage({super.key, required this.pendingPlants});

  final List<PlantModel> pendingPlants;

  @override
  State<ProcessingPage> createState() => _ProcessingPageState();
}

class _ProcessingPageState extends State<ProcessingPage> {
  final PlantService _plantService = PlantService();
  late List<PlantModel> _displayedPlants;
  final LocalGuestService _localGuestService = LocalGuestService();

  @override
  void initState() {
    super.initState();
    _displayedPlants = List.from(widget.pendingPlants);
  }

  bool _hasFullResult(PlantModel plant) {
    final ar = plant.analysisResults;
    return ar != null &&
        (ar['detectedDisease'] as String?) != null &&
        (ar['detectedDisease'] as String?) != 'N/A' &&
        ar['confidence'] != null &&
        (ar['recommendation'] as String?) != null &&
        ((ar['recommendation'] as String?)?.isNotEmpty ?? false);
  }

  void _refreshProcessingList() async {
    try {
      final plants = _localGuestService.isLocalGuestMode() ?
                      await _localGuestService.getPlants() :
                      await _plantService.getUserPlants();
      final List<PlantModel> pendingPlants;
      if (_localGuestService.isLocalGuestMode()) {
        pendingPlants =
            plants
                .where(
                  (p) =>
                      p.status == 'pending' ||
                      p.status == 'processing' ||
                      p.status == 'analyzing' ||
                      (p.status == 'completed' && !_hasFullResult(p)),
                )
                .toList();
      } else {
        pendingPlants =
            plants
                .where(
                  (p) =>
                      p.status == 'pending' ||
                      p.status == 'processing' ||
                      p.status == 'analyzing',
                )
                .toList();
      }

      if (mounted) {
        setState(() {
          _displayedPlants = pendingPlants;
        });
      }
    } catch (e) {
      logger.e('Error refreshing processing list: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AppbarWidget(),
      body:
          _displayedPlants.isEmpty
              ? const Center(
                child: Text(
                  "No plants currently processing.",
                  style: TextStyle(color: Colors.grey),
                ),
              )
              : ListView.builder(
                padding: const EdgeInsets.all(12.0),
                itemCount: _displayedPlants.length,
                itemBuilder: (context, index) {
                  final plant = _displayedPlants[index];
                  final imageId =
                      plant.images.isNotEmpty ? plant.images.first : null;

                  if (_localGuestService.isLocalGuestMode()) {
                    final ar = plant.analysisResults;
                    final hasDet =
                        ar != null &&
                        ar.containsKey('detectedDisease') &&
                        ar['detectedDisease'] != null &&
                        ar.containsKey('confidence') &&
                        ar['confidence'] != null;
                    final hasFull = _hasFullResult(plant);
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4.0),
                      child: CardWidget(
                        title:
                            (hasFull || hasDet)
                                ? (plant.analysisResults?['plantName'] ??
                                    'Plant Analysis Results')
                                : 'Plant Analysis in Progress',
                        description:
                            hasFull
                                ? (plant.analysisResults?['description'] ??
                                    'Analysis completed')
                                : hasDet
                                ? 'Detection available — tap to open (AI suggestion may still be loading)'
                                : (plant.status == 'processing' ||
                                        plant.status == 'analyzing')
                                ? 'Processing...'
                                : 'Pending analysis...',
                        completed: hasFull,
                        imageId: imageId,
                        plantId: plant.plantId,
                        onDelete: _refreshProcessingList,
                      ),
                    );
                  }

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                    child: CardWidget(
                      title: 'Plant Analysis in Progress',
                      description:
                          (plant.status == 'processing' ||
                                  plant.status == 'analyzing')
                              ? 'Processing...'
                              : 'Pending analysis...',
                      completed: false,
                      imageId: imageId,
                      plantId: plant.plantId,
                      onDelete: _refreshProcessingList,
                    ),
                  );
                },
              ),
    );
  }
}
