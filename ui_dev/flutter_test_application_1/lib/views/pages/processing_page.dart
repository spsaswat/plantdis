import 'package:flutter/material.dart';
import 'package:flutter_test_application_1/models/plant_model.dart';
import 'package:flutter_test_application_1/views/widgets/appbar_widget.dart';
import 'package:flutter_test_application_1/views/widgets/card_widget.dart';

class ProcessingPage extends StatelessWidget {
  const ProcessingPage({super.key, required this.pendingPlants});

  final List<PlantModel> pendingPlants;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppbarWidget(),
      body:
          pendingPlants.isEmpty
              ? Center(
                child: Text(
                  "No plants currently processing.",
                  style: TextStyle(color: Colors.grey),
                ),
              )
              : ListView.builder(
                padding: const EdgeInsets.all(12.0),
                itemCount: pendingPlants.length,
                itemBuilder: (context, index) {
                  final plant = pendingPlants[index];
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
                    ),
                  );
                },
              ),
    );
  }
}
