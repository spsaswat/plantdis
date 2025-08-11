import 'package:flutter/material.dart';
import 'package:flutter_test_application_1/models/plant_model.dart';
import 'package:flutter_test_application_1/services/plant_service.dart';
import 'package:flutter_test_application_1/views/widgets/appbar_widget.dart';
import 'package:flutter_test_application_1/views/widgets/card_widget.dart';

class ProcessingPage extends StatefulWidget {
  const ProcessingPage({super.key, required this.pendingPlants});

  final List<PlantModel> pendingPlants;

  @override
  State<ProcessingPage> createState() => _ProcessingPageState();
}

class _ProcessingPageState extends State<ProcessingPage> {
  final PlantService _plantService = PlantService();
  late List<PlantModel> _displayedPlants;

  @override
  void initState() {
    super.initState();
    _displayedPlants = List.from(widget.pendingPlants);
  }

  void _refreshProcessingList() async {
    try {
      final plants = await _plantService.getUserPlants();
      final pendingPlants =
          plants
              .where(
                (p) =>
                    p.status == 'pending' ||
                    p.status == 'processing' ||
                    p.status == 'analyzing',
              )
              .toList();

      if (mounted) {
        setState(() {
          _displayedPlants = pendingPlants;
        });
      }
    } catch (e) {
      print('Error refreshing processing list: $e');
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
