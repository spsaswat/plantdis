import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test_application_1/models/plant_model.dart';
import 'package:flutter_test_application_1/models/image_model.dart';
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
  List<CardWidget> _completedPlantsList = [];
  List<CardWidget> _pendingPlantsList = [];
  bool _isLoading = true;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _loadUserPlants();
  }

  Future<void> _loadUserPlants() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      // Load all plants
      List<PlantModel> plants = await _plantService.getUserPlants();

      // Split plants into completed and pending based on status
      var completedPlants =
          plants.where((plant) => plant.status == 'completed').toList();
      var pendingPlants =
          plants
              .where(
                (plant) =>
                    plant.status == 'pending' || plant.status == 'processing',
              )
              .toList();

      // Load all images for these plants in one batch instead of per plant
      Map<String, List<ImageModel>> plantImagesMap = {};

      // Fetch images for all plants in one go
      for (var plant in [...completedPlants, ...pendingPlants]) {
        if (plant.images.isNotEmpty) {
          try {
            var images = await _plantService.getPlantImages(plant.plantId);
            plantImagesMap[plant.plantId] = images;
          } catch (e) {
            print('Error fetching images for plant ${plant.plantId}: $e');
            // Continue with other plants even if one fails
            plantImagesMap[plant.plantId] = [];
          }
        } else {
          plantImagesMap[plant.plantId] = [];
        }
      }

      // Convert to CardWidget objects with fetched images
      _completedPlantsList =
          completedPlants.map((plant) {
            var images = plantImagesMap[plant.plantId] ?? [];
            var firstImage = images.isNotEmpty ? images.first : null;

            return CardWidget(
              title:
                  plant.analysisResults?['plantName'] ??
                  'Plant Analysis Results',
              description:
                  plant.analysisResults?['description'] ?? 'Analysis completed',
              imgSrc: firstImage?.originalUrl ?? '',
              completed: true,
              imageId: firstImage?.imageId,
              plantId: plant.plantId,
            );
          }).toList();

      _pendingPlantsList =
          pendingPlants.map((plant) {
            var images = plantImagesMap[plant.plantId] ?? [];
            var firstImage = images.isNotEmpty ? images.first : null;

            return CardWidget(
              title: 'Plant Analysis in Progress',
              description:
                  plant.status == 'processing'
                      ? 'Processing'
                      : 'Pending analysis',
              imgSrc: firstImage?.originalUrl ?? '',
              completed: false,
              imageId: firstImage?.imageId,
              plantId: plant.plantId,
            );
          }).toList();

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error loading plants: $e';
      });
      print('Error loading plants: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      heightFactor: 1,
      child: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.all(20.0),
          child: LayoutBuilder(
            builder: (context, constraints) {
              return FractionallySizedBox(
                widthFactor: constraints.maxWidth > 500 ? 0.5 : 1,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    HeroWidget(title: "PlantDis"),
                    SizedBox(height: 10.0),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text("Results (${_completedPlantsList.length})"),
                        TextButton(
                          onPressed:
                              () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder:
                                      (context) => ResultsPage(
                                        cardList: _completedPlantsList,
                                      ),
                                ),
                              ),
                          child: Text("View all"),
                        ),
                      ],
                    ),
                    Divider(),
                    ..._completedPlantsList.take(2),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text("Processing (${_pendingPlantsList.length})"),
                        TextButton(
                          onPressed:
                              () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder:
                                      (context) => ProcessingPage(
                                        cardList: _pendingPlantsList,
                                      ),
                                ),
                              ),
                          child: Text("View all"),
                        ),
                      ],
                    ),
                    Divider(),
                    ..._pendingPlantsList.take(2),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
