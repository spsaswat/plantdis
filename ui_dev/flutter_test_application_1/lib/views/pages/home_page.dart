import 'package:flutter/material.dart';
import 'package:flutter_test_application_1/models/plant_model.dart';
import 'package:flutter_test_application_1/services/plant_service.dart';
import 'package:flutter_test_application_1/views/pages/processing_page.dart';
import 'package:flutter_test_application_1/views/pages/results_page.dart';
import 'package:flutter_test_application_1/views/widgets/card_widget.dart';
import 'package:flutter_test_application_1/services/local_guest_service.dart';
import '../widgets/hero_widget.dart';
import '../../utils/route_observer.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with RouteAware {
  final PlantService _plantService = PlantService();
  final LocalGuestService _localGuestService = LocalGuestService();

  /// One subscription for the whole HomePage lifetime. Creating a new
  /// `userPlantsStream()` on every build drops the old listener and can miss
  /// local-guest broadcast updates (delete / analysis) so the list never refreshes.
  late final Stream<List<PlantModel>> _userPlantsStream;

  @override
  void initState() {
    super.initState();
    _userPlantsStream = _plantService.userPlantsStream();
  }

  void _refreshAfterCardAction() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final ModalRoute<dynamic>? route = ModalRoute.of(context);
    if (route is PageRoute) {
      routeObserver.subscribe(this, route);
    }
  }

  // Called when coming back to this page (e.g., from SegmentPage)
  @override
  void didPopNext() {
    if (mounted) setState(() {});
  }

  /// Disease + confidence + non-empty AI recommendation (same bar as Results list).
  bool _plantHasFullResult(PlantModel plant) {
    final ar = plant.analysisResults;
    return ar != null &&
        (ar['detectedDisease'] as String?) != null &&
        (ar['detectedDisease'] as String?) != 'N/A' &&
        ar['confidence'] != null &&
        (ar['recommendation'] as String?) != null &&
        ((ar['recommendation'] as String?)?.isNotEmpty ?? false);
  }

  bool _plantHasDetectionSummary(PlantModel plant) {
    final ar = plant.analysisResults;
    return ar != null &&
        ar.containsKey('detectedDisease') &&
        ar['detectedDisease'] != null &&
        ar.containsKey('confidence') &&
        ar['confidence'] != null;
  }

  Map<String, List<PlantModel>> _getPlantLists(List<PlantModel> plants) {
    List<PlantModel> completed = [];
    List<PlantModel> pending = [];

    for (var plant in plants) {
      final hasFullResult = _plantHasFullResult(plant);

      // Only items with complete results (disease + confidence + recommendation)
      // are shown in Results; all others remain in Processing.
      if (plant.status == 'completed' && hasFullResult) {
        completed.add(plant);
      } else if (plant.status == 'pending' ||
          plant.status == 'processing' ||
          plant.status == 'analyzing' ||
          (plant.status == 'completed' && !hasFullResult)) {
        pending.add(plant);
      }
    }
    return {'completed': completed, 'pending': pending};
  }

  DateTime _parseDetectionTimestamp(Map<String, dynamic>? analysisResults) {
    try {
      final ts = analysisResults?['detectionTimestamp'] as String?;
      if (ts == null) return DateTime.fromMillisecondsSinceEpoch(0);
      return DateTime.parse(ts);
    } catch (_) {
      return DateTime.fromMillisecondsSinceEpoch(0);
    }
  }

  int _compareByNewest(
    PlantModel a,
    PlantModel b, {
    bool preferDetectionTs = true,
  }) {
    DateTime timeA;
    DateTime timeB;
    if (preferDetectionTs) {
      timeA = _parseDetectionTimestamp(a.analysisResults);
      timeB = _parseDetectionTimestamp(b.analysisResults);
      if (timeA.millisecondsSinceEpoch == 0 &&
          timeB.millisecondsSinceEpoch == 0) {
        timeA = a.createdAt;
        timeB = b.createdAt;
      } else {
        if (timeA.millisecondsSinceEpoch == 0) timeA = a.createdAt;
        if (timeB.millisecondsSinceEpoch == 0) timeB = b.createdAt;
      }
    } else {
      timeA = a.createdAt;
      timeB = b.createdAt;
    }
    // Newest first
    return timeB.compareTo(timeA);
  }

  List<CardWidget> _buildCardsFromPlants(List<PlantModel> plants) {
    return plants.map((plant) {
      final firstImageId = plant.images.isNotEmpty ? plant.images.first : null;

      if (_localGuestService.isLocalGuestMode()) {
        final hasFull = _plantHasFullResult(plant);
        final hasDet = _plantHasDetectionSummary(plant);
        return CardWidget(
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
                  : ((plant.status == 'processing' ||
                          plant.status == 'analyzing')
                      ? 'Processing'
                      : 'Pending analysis'),
          completed: hasFull,
          imageId: firstImageId,
          plantId: plant.plantId,
          onDelete: _refreshAfterCardAction,
        );
      }

      final hasDetection = _plantHasDetectionSummary(plant);
      final isCompleted = (plant.status == 'completed') && hasDetection;
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
        onDelete: _refreshAfterCardAction,
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<PlantModel>>(
      stream: _userPlantsStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          // Waiting for connection
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
        final completedPlants =
            plantLists['completed']!
              ..sort((a, b) => _compareByNewest(a, b, preferDetectionTs: true));
        final pendingPlants =
            plantLists['pending']!..sort(
              (a, b) => _compareByNewest(a, b, preferDetectionTs: false),
            );

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
