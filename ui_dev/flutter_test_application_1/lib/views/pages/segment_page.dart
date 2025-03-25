import 'package:flutter/material.dart';
import 'package:flutter_test_application_1/data/constants.dart';
import 'package:flutter_test_application_1/services/plant_service.dart';
import 'package:flutter_test_application_1/views/widgets/appbar_widget.dart';
import 'package:flutter_test_application_1/views/widgets/segment_hero_widget.dart';

class SegmentPage extends StatefulWidget {
  const SegmentPage({
    super.key,
    required this.imgSrc,
    required this.id,
    this.plantId,
  });

  final String imgSrc;
  final String id;
  final String? plantId;

  @override
  State<SegmentPage> createState() => _SegmentPageState();
}

class _SegmentPageState extends State<SegmentPage> {
  final PlantService _plantService = PlantService();
  bool _isLoading = true;
  String _errorMessage = '';
  Map<String, dynamic>? _analysisResults;

  @override
  void initState() {
    super.initState();
    _loadPlantData();
  }

  Future<void> _loadPlantData() async {
    if (widget.plantId == null) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Plant ID not provided';
      });
      return;
    }

    try {
      var plants = await _plantService.getUserPlants();
      var plantMatch =
          plants.where((p) => p.plantId == widget.plantId).toList();

      if (plantMatch.isEmpty) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Plant not found';
        });
        return;
      }

      var plant = plantMatch.first;

      setState(() {
        _analysisResults = plant.analysisResults ?? {};
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error loading plant data: $e';
      });
      print('Error loading plant data: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppbarWidget(),
      body: Center(
        heightFactor: 1,
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: LayoutBuilder(
              builder: (context, constraints) {
                return FractionallySizedBox(
                  widthFactor: constraints.maxWidth > 500 ? 0.5 : 1,
                  child:
                      _isLoading
                          ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                CircularProgressIndicator(),
                                SizedBox(height: 20),
                                Text('Loading plant analysis...'),
                              ],
                            ),
                          )
                          : _errorMessage.isNotEmpty
                          ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.error_outline,
                                  size: 48,
                                  color: Colors.red,
                                ),
                                SizedBox(height: 20),
                                Text(_errorMessage),
                                SizedBox(height: 20),
                                ElevatedButton(
                                  onPressed: _loadPlantData,
                                  child: Text('Try Again'),
                                ),
                              ],
                            ),
                          )
                          : Column(
                            spacing: 10.0,
                            children: [
                              SegmentHero(imgSrc: widget.imgSrc, id: widget.id),
                              Container(
                                width: double.infinity,
                                padding: EdgeInsets.symmetric(vertical: 10.0),
                                child: Card(
                                  child: Padding(
                                    padding: const EdgeInsets.all(15.0),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      spacing: 5.0,
                                      children: [
                                        Center(
                                          child: Text(
                                            "Analysis Results",
                                            style: KTextStyle.titleTealText,
                                          ),
                                        ),
                                        if (_analysisResults != null) ...[
                                          for (var entry
                                              in _analysisResults!.entries)
                                            if (entry.value != null)
                                              Padding(
                                                padding: const EdgeInsets.only(
                                                  top: 8.0,
                                                ),
                                                child: Row(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      "${entry.key}: ",
                                                      style:
                                                          KTextStyle
                                                              .termTealText,
                                                    ),
                                                    Expanded(
                                                      child: Text(
                                                        "${entry.value}",
                                                        style:
                                                            KTextStyle
                                                                .descriptionText,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                        ] else
                                          Text(
                                            "No analysis results available",
                                            style: KTextStyle.descriptionText,
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
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
