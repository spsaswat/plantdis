import 'package:flutter/material.dart';
import 'package:flutter_test_application_1/models/detection_history_entry.dart';
import 'package:flutter_test_application_1/services/plant_service.dart';
import 'package:flutter_test_application_1/views/pages/segment_page.dart';
import 'package:intl/intl.dart';

/// A card widget for displaying an entry in the detection history
class DetectionHistoryCard extends StatefulWidget {
  final DetectionHistoryEntry entry;

  const DetectionHistoryCard({Key? key, required this.entry}) : super(key: key);

  @override
  State<DetectionHistoryCard> createState() => _DetectionHistoryCardState();
}

class _DetectionHistoryCardState extends State<DetectionHistoryCard> {
  final PlantService _plantService = PlantService();
  String? _imageUrl;
  bool _isLoadingImage = true;

  @override
  void initState() {
    super.initState();
    _loadImageUrl();
  }

  Future<void> _loadImageUrl() async {
    if (widget.entry.analyzedImageId == null) {
      setState(() {
        _isLoadingImage = false;
      });
      return;
    }

    try {
      final images = await _plantService.getPlantImages(
        widget.entry.plant.plantId,
      );
      final imageMatch =
          images
              .where((img) => img.imageId == widget.entry.analyzedImageId)
              .firstOrNull;

      setState(() {
        _imageUrl = imageMatch?.originalUrl;
        _isLoadingImage = false;
      });
    } catch (e) {
      print('Error loading image for history card: $e');
      setState(() {
        _isLoadingImage = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final entry = widget.entry;
    final hasConfidence = entry.confidence > 0.0;

    // Determine color based on status
    Color statusColor;
    if (entry.isError) {
      statusColor = Colors.red.shade300;
    } else if (!entry.hasResults) {
      statusColor = Colors.orange.shade300;
    } else {
      statusColor =
          entry.confidence >= 0.7
              ? Colors.green.shade300
              : (entry.confidence >= 0.4
                  ? Colors.orange.shade300
                  : Colors.red.shade300);
    }

    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: statusColor.withOpacity(0.5), width: 1),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          // Only navigate to detailed view if we have a valid image
          if (_imageUrl != null && entry.analyzedImageId != null) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder:
                    (context) => SegmentPage(
                      imgSrc: _imageUrl!,
                      id: entry.analyzedImageId!,
                      plantId: entry.plant.plantId,
                    ),
              ),
            );
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Date and status row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    entry.analysisDate,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      entry.status,
                      style: TextStyle(
                        color: statusColor.shade700,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),

              const Divider(height: 24),

              // Image and result row
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Thumbnail
                  SizedBox(
                    width: 80,
                    height: 80,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child:
                          _isLoadingImage
                              ? const Center(child: CircularProgressIndicator())
                              : (_imageUrl != null
                                  ? Image.network(
                                    _imageUrl!,
                                    fit: BoxFit.cover,
                                    errorBuilder:
                                        (context, error, stackTrace) =>
                                            const Icon(
                                              Icons.broken_image,
                                              size: 40,
                                              color: Colors.grey,
                                            ),
                                  )
                                  : const Icon(
                                    Icons.image_not_supported,
                                    size: 40,
                                    color: Colors.grey,
                                  )),
                    ),
                  ),

                  const SizedBox(width: 16),

                  // Results
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          entry.diseaseName,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),

                        if (hasConfidence)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: RichText(
                              text: TextSpan(
                                style: DefaultTextStyle.of(context).style,
                                children: [
                                  const TextSpan(
                                    text: 'Confidence: ',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w500,
                                      color: Colors.black54,
                                    ),
                                  ),
                                  TextSpan(
                                    text:
                                        '${(entry.confidence * 100).toStringAsFixed(1)}%',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color:
                                          entry.confidence >= 0.7
                                              ? Colors.green.shade700
                                              : (entry.confidence >= 0.4
                                                  ? Colors.orange.shade700
                                                  : Colors.red.shade700),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                        if (entry.plantType != 'Unknown')
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              'Plant: ${entry.plantType}',
                              style: const TextStyle(color: Colors.black54),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
