import 'package:flutter/material.dart';
import 'package:flutter_test_application_1/views/widgets/appbar_widget.dart';
import 'package:flutter_test_application_1/views/widgets/card_widget.dart';
import 'package:flutter_test_application_1/views/widgets/hero_widget.dart';
import 'package:flutter_test_application_1/services/plant_service.dart';
import 'package:flutter_test_application_1/utils/ui_utils.dart';

class ResultsPage extends StatefulWidget {
  const ResultsPage({super.key, required this.cardList});

  final List<CardWidget> cardList;

  @override
  State<ResultsPage> createState() => _ResultsPageState();
}

class _ResultsPageState extends State<ResultsPage> {
  final PlantService _plantService = PlantService();
  late List<CardWidget> _displayedCards;

  @override
  void initState() {
    super.initState();
    _displayedCards = List.from(widget.cardList);
  }

  void _refreshCards() async {
    // Fetch latest completed plants
    final plants = await _plantService.getUserPlants();
    final completedPlants =
        plants.where((p) => p.status == 'completed').toList();

    final updatedCards =
        completedPlants.map((plant) {
          final firstImageId =
              plant.images.isNotEmpty ? plant.images.first : null;

          // Get disease name from analysis results
          String diseaseName = 'No disease detected';
          if (plant.analysisResults != null &&
              plant.analysisResults!.containsKey('detectedDisease')) {
            diseaseName =
                plant.analysisResults!['detectedDisease'] as String? ??
                diseaseName;

            // Format disease name to show spaces instead of underscores
            diseaseName = UIUtils.formatDiseaseName(diseaseName);
          }

          return CardWidget(
            title: 'Analysis Results',
            description: diseaseName,
            completed: true,
            imageId: firstImageId,
            plantId: plant.plantId,
            onDelete: _refreshCards,
          );
        }).toList();

    if (mounted) {
      setState(() {
        _displayedCards = updatedCards;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AppbarWidget(),
      body: Center(
        heightFactor: 1,
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: LayoutBuilder(
              builder: (context, constraints) {
                return FractionallySizedBox(
                  widthFactor: constraints.maxWidth > 500 ? 0.5 : 1,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      const HeroWidget(title: "Results"),
                      const SizedBox(height: 10.0),
                      if (_displayedCards.isEmpty)
                        const Text(
                          "No results available.",
                          style: TextStyle(color: Colors.grey),
                        )
                      else
                        ..._displayedCards.map((card) {
                          // Return a new CardWidget with the onDelete callback
                          return CardWidget(
                            title: card.title,
                            description: card.description,
                            completed: card.completed,
                            imageId: card.imageId,
                            plantId: card.plantId,
                            onDelete: _refreshCards,
                          );
                        }),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
