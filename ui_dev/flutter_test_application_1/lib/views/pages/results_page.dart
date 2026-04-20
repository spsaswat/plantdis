import 'package:flutter/material.dart';
import 'package:flutter_test_application_1/models/plant_model.dart';
import 'package:flutter_test_application_1/views/widgets/appbar_widget.dart';
import 'package:flutter_test_application_1/views/widgets/card_widget.dart';
import 'package:flutter_test_application_1/views/widgets/hero_widget.dart';
import 'package:flutter_test_application_1/services/plant_service.dart';
import 'package:flutter_test_application_1/services/local_guest_service.dart';
import 'package:flutter_test_application_1/utils/ui_utils.dart';

class ResultsPage extends StatefulWidget {
  const ResultsPage({super.key, required this.cardList});

  final List<CardWidget> cardList;

  @override
  State<ResultsPage> createState() => _ResultsPageState();
}

class _ResultsPageState extends State<ResultsPage> {
  final PlantService _plantService = PlantService();
  final LocalGuestService _localGuestService = LocalGuestService();
  late List<CardWidget> _displayedCards;

  @override
  void initState() {
    super.initState();
    _displayedCards = List.from(widget.cardList);
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

  void _refreshCards() async {
    final plants = await _plantService.getUserPlants();
    final completedPlants =
        plants
            .where(
              (p) =>
                  p.status == 'completed' &&
                  (_localGuestService.isLocalGuestMode()
                      ? _hasFullResult(p)
                      : true),
            )
            .toList();

    final updatedCards =
        completedPlants.map((plant) {
          final firstImageId =
              plant.images.isNotEmpty ? plant.images.first : null;

          String diseaseName = 'No disease detected';
          if (plant.analysisResults != null &&
              plant.analysisResults!.containsKey('detectedDisease')) {
            diseaseName =
                plant.analysisResults!['detectedDisease'] as String? ??
                diseaseName;
            diseaseName = UIUtils.formatDiseaseName(diseaseName);
          }

          if (_localGuestService.isLocalGuestMode()) {
            return CardWidget(
              title:
                  plant.analysisResults?['plantName'] ??
                  'Plant Analysis Results',
              description:
                  (plant.analysisResults?['description'] as String?) ??
                      diseaseName,
              completed: true,
              imageId: firstImageId,
              plantId: plant.plantId,
              onDelete: _refreshCards,
            );
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
