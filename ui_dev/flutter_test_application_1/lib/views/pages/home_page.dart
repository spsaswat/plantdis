import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test_application_1/models/plant_model.dart';
import 'package:flutter_test_application_1/services/plant_service.dart';
import 'package:flutter_test_application_1/views/pages/processing_page.dart';
import 'package:flutter_test_application_1/views/pages/results_page.dart';
import 'package:flutter_test_application_1/views/widgets/card_widget.dart';
import '../widgets/hero_widget.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final PlantService _plantService = PlantService();

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Map<String, List<PlantModel>> _getPlantLists(List<PlantModel> plants) {
    List<PlantModel> completed = [];
    List<PlantModel> pending = [];

    for (var plant in plants) {
      if (plant.status == 'completed') {
        completed.add(plant);
      } else if (plant.status == 'pending' ||
          plant.status == 'processing' ||
          plant.status == 'analyzing') {
        pending.add(plant);
      }
    }
    return {'completed': completed, 'pending': pending};
  }

  List<CardWidget> _buildCardsFromPlants(List<PlantModel> plants) {
    return plants.map((plant) {
      final firstImageId = plant.images.isNotEmpty ? plant.images.first : null;
      final isCompleted = plant.status == 'completed';

      return CardWidget(
        title:
            isCompleted
                ? (plant.analysisResults?['plantName'] ??
                    'Plant Analysis Results')
                : 'Plant Analysis in Progress',
        description:
            isCompleted
                ? (plant.analysisResults?['description'] ??
                    'Analysis completed')
                : ((plant.status == 'processing' || plant.status == 'analyzing')
                    ? 'Processing'
                    : 'Pending analysis'),
        completed: isCompleted,
        imageId: firstImageId,
        plantId: plant.plantId,
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<PlantModel>>(
      stream: _plantService.userPlantsStream(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Loading plants...'),
              ],
            ),
          );
        }

        final allPlants = snapshot.data!;
        final plantLists = _getPlantLists(allPlants);
        final completedPlants = plantLists['completed']!;
        final pendingPlants = plantLists['pending']!;

        final completedCards = _buildCardsFromPlants(completedPlants);
        final pendingCards = _buildCardsFromPlants(pendingPlants);

        return Center(
          heightFactor: 1,
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return FractionallySizedBox(
                    widthFactor: constraints.maxWidth > 500 ? 0.5 : 1,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const HeroWidget(title: "PlantDis"),
                        const SizedBox(height: 10.0),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text("Results (${completedCards.length})"),
                            TextButton(
                              onPressed:
                                  () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder:
                                          (context) => ResultsPage(
                                            cardList: completedCards,
                                          ),
                                    ),
                                  ),
                              child: const Text("View all"),
                            ),
                          ],
                        ),
                        const Divider(),
                        ...completedCards.take(2),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text("Processing (${pendingCards.length})"),
                            TextButton(
                              onPressed:
                                  () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder:
                                          (context) => ProcessingPage(
                                            pendingPlants: pendingPlants,
                                          ),
                                    ),
                                  ),
                              child: const Text("View all"),
                            ),
                          ],
                        ),
                        const Divider(),
                        ...pendingCards.take(2),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}
