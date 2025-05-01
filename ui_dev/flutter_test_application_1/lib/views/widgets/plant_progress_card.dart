import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test_application_1/models/analysis_progress.dart';
import 'package:flutter_test_application_1/services/detection_service.dart';
import 'package:flutter_test_application_1/views/widgets/analysis_progress_widget.dart';
import 'package:flutter_test_application_1/models/image_model.dart';
import 'package:flutter_test_application_1/services/plant_service.dart';

/// A card that displays the analysis progress for a specific plant.
class PlantProgressCard extends StatefulWidget {
  const PlantProgressCard({super.key, required this.plantId, this.imageId});

  final String plantId;
  final String? imageId;

  @override
  State<PlantProgressCard> createState() => _PlantProgressCardState();
}

class _PlantProgressCardState extends State<PlantProgressCard> {
  final DetectionService _detectionService = DetectionService();
  final PlantService _plantService = PlantService();
  Stream<AnalysisProgress>? _progressStream;
  bool _streamInitiallyNull = false;
  Future<String?>? _imageUrlFuture;

  @override
  void initState() {
    super.initState();
    _progressStream = _detectionService.getProgressStream(widget.plantId);
    if (_progressStream == null) {
      print(
        '[PlantProgressCard] initState: Progress Stream for plantId ${widget.plantId} not found (null).',
      );
      _streamInitiallyNull = true;
    } else {
      print(
        '[PlantProgressCard] initState: Progress Stream found for plantId ${widget.plantId}.',
      );
    }

    if (widget.imageId != null) {
      print(
        '[PlantProgressCard] initState: Fetching image URL for imageId ${widget.imageId}.',
      );
      _imageUrlFuture = _fetchImageUrl(widget.plantId, widget.imageId!);
    } else {
      print(
        '[PlantProgressCard] initState: No imageId provided for plantId ${widget.plantId}.',
      );
    }
  }

  Future<String?> _fetchImageUrl(String plantId, String imageId) async {
    try {
      List<ImageModel> images = await _plantService.getPlantImages(plantId);
      var imageMatch =
          images.where((img) => img.imageId == imageId).firstOrNull;
      if (imageMatch?.originalUrl != null) {
        print(
          '[PlantProgressCard] _fetchImageUrl: Found URL for $plantId/$imageId',
        );
      } else {
        print(
          '[PlantProgressCard] _fetchImageUrl: URL *not* found for $plantId/$imageId',
        );
      }
      return imageMatch?.originalUrl;
    } catch (e) {
      print(
        '[PlantProgressCard] Error fetching image URL for CardWidget ($plantId/$imageId): $e',
      );
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_streamInitiallyNull) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Center(
            child: Text(
              'Analysis session for Plant ID ${widget.plantId} not active or already completed.',
              style: TextStyle(color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              width: 60.0,
              height: 60.0,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4.0),
                child: _buildImageThumbnail(),
              ),
            ),
            const SizedBox(width: 16.0),

            Expanded(
              child: StreamBuilder<AnalysisProgress>(
                stream: _progressStream,
                initialData: AnalysisProgress(
                  stage: AnalysisStage.preprocessing,
                  progress: 0.0,
                  message: 'Connecting to analysis stream...',
                ),
                builder: (context, snapshot) {
                  if (snapshot.hasData) {
                    print(
                      '[PlantProgressCard] build: Received progress update for ${widget.plantId}: ${snapshot.data?.stage} ${snapshot.data?.progress}',
                    );
                  } else if (snapshot.hasError) {
                    print(
                      '[PlantProgressCard] build: Stream error for ${widget.plantId}: ${snapshot.error}',
                    );
                  } else if (snapshot.connectionState == ConnectionState.done) {
                    print(
                      '[PlantProgressCard] build: Stream done for ${widget.plantId}.',
                    );
                  }

                  if (snapshot.connectionState == ConnectionState.waiting &&
                      !snapshot.hasData) {
                    return _buildProgressDisplay(snapshot.data!);
                  }

                  if (snapshot.connectionState == ConnectionState.done) {
                    return Center(
                      child: Text(
                        'Analysis stream for Plant ID ${widget.plantId} closed.',
                        style: TextStyle(color: Colors.grey),
                        textAlign: TextAlign.center,
                      ),
                    );
                  }

                  if (snapshot.hasError) {
                    return Center(
                      child: Text(
                        'Stream Error: ${snapshot.error}',
                        style: TextStyle(color: Colors.red),
                      ),
                    );
                  }

                  return _buildProgressDisplay(snapshot.requireData);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageThumbnail() {
    if (widget.imageId == null || _imageUrlFuture == null) {
      return Container(
        color: Colors.grey.shade300,
        child: Icon(
          Icons.image_not_supported_outlined,
          color: Colors.grey.shade600,
        ),
      );
    }

    return FutureBuilder<String?>(
      future: _imageUrlFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        }
        if (snapshot.hasError || !snapshot.hasData || snapshot.data == null) {
          print(
            '[PlantProgressCard] Image FutureBuilder Error/NoData for ${widget.plantId}/${widget.imageId}: Error: ${snapshot.error}, HasData: ${snapshot.hasData}',
          );
          return Container(
            color: Colors.grey.shade300,
            child: Icon(Icons.error_outline, color: Colors.red.shade400),
          );
        }

        final imageUrl = snapshot.data!;
        return Image.network(
          imageUrl,
          fit: BoxFit.cover,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  value:
                      loadingProgress.expectedTotalBytes != null
                          ? loadingProgress.cumulativeBytesLoaded /
                              loadingProgress.expectedTotalBytes!
                          : null,
                ),
              ),
            );
          },
          errorBuilder: (context, error, stackTrace) {
            print(
              '[PlantProgressCard] Image.network Error for ${widget.plantId}/${widget.imageId}: $error',
            );
            return Container(
              color: Colors.grey.shade300,
              child: Icon(
                Icons.broken_image_outlined,
                color: Colors.grey.shade600,
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildProgressDisplay(AnalysisProgress progress) {
    if (progress.stage == AnalysisStage.failed) {
      return Center(
        child: Text(
          'Analysis Failed: ${progress.errorMessage ?? 'Unknown error'}',
          style: const TextStyle(color: Colors.red),
          textAlign: TextAlign.center,
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          "Analysis for Plant ID: ${widget.plantId}",
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: Colors.grey),
        ),
        SizedBox(height: 10),
        AnalysisProgressWidget(progress: progress),
      ],
    );
  }
}
