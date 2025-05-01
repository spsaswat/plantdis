import 'package:flutter/material.dart';
import 'package:flutter_test_application_1/models/image_model.dart';
import 'package:flutter_test_application_1/services/plant_service.dart';
import 'package:flutter_test_application_1/views/pages/segment_page.dart';
import 'package:flutter_test_application_1/views/widgets/segment_hero_widget.dart';

import '../../data/constants.dart';

class CardWidget extends StatefulWidget {
  CardWidget({
    super.key,
    required this.title,
    required this.description,
    required this.completed,
    this.imageId,
    required this.plantId,
  });

  final String title;
  final String description;
  final bool completed;
  final String? imageId;
  final String plantId;

  @override
  State<CardWidget> createState() => _CardWidgetState();
}

class _CardWidgetState extends State<CardWidget> {
  final PlantService _plantService = PlantService();
  Future<String?>? _imageUrlFuture;
  String? _heroTag;

  @override
  void initState() {
    super.initState();
    _heroTag = widget.imageId ?? widget.plantId + UniqueKey().toString();
    if (widget.plantId != null && widget.imageId != null) {
      _imageUrlFuture = _fetchImageUrl(widget.plantId, widget.imageId!);
    }
  }

  Future<String?> _fetchImageUrl(String plantId, String imageId) async {
    try {
      List<ImageModel> images = await _plantService.getPlantImages(plantId);
      var imageMatch =
          images.where((img) => img.imageId == imageId).firstOrNull;
      return imageMatch?.originalUrl;
    } catch (e) {
      print('Error fetching image URL for CardWidget ($plantId/$imageId): $e');
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(10);

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(vertical: 5.0),
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: borderRadius),
        color: widget.completed ? null : Colors.white12,
        child: InkWell(
          borderRadius: borderRadius,
          onTap:
              widget.completed && _imageUrlFuture != null
                  ? () async {
                    String? resolvedImgSrc = await _imageUrlFuture;
                    if (resolvedImgSrc != null && mounted) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder:
                              (context) => SegmentPage(
                                imgSrc: resolvedImgSrc,
                                id: _heroTag!,
                                plantId: widget.plantId,
                              ),
                        ),
                      );
                    }
                  }
                  : null,
          child: Padding(
            padding: const EdgeInsets.all(15.0),
            child: Row(
              children: [
                SizedBox(
                  width: 50.0,
                  height: 50.0,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(3.0),
                    child: FutureBuilder<String?>(
                      future: _imageUrlFuture,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return Center(
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          );
                        }
                        if (snapshot.hasError ||
                            !snapshot.hasData ||
                            snapshot.data == null) {
                          return Image.asset(
                            'assets/images/error_icon.png',
                            fit: BoxFit.cover,
                          );
                        }

                        final imageUrl = snapshot.data!;
                        final imageWidget = Image.network(
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
                                          ? loadingProgress
                                                  .cumulativeBytesLoaded /
                                              loadingProgress
                                                  .expectedTotalBytes!
                                          : null,
                                ),
                              ),
                            );
                          },
                          errorBuilder: (context, error, stackTrace) {
                            return Image.asset(
                              'assets/images/error_icon.png',
                              fit: BoxFit.cover,
                            );
                          },
                        );

                        if (widget.completed) {
                          return SegmentHero(imgSrc: imageUrl, id: _heroTag!);
                        } else {
                          return Opacity(opacity: 0.75, child: imageWidget);
                        }
                      },
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 15.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(widget.title, style: KTextStyle.titleTealText),
                        Text(
                          widget.description,
                          style: KTextStyle.descriptionText,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
