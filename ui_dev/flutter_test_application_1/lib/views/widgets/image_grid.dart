import 'package:flutter/material.dart';
import 'package:flutter_test_application_1/views/widgets/image_card.dart';

class ImageGrid extends StatefulWidget {
  final List<Map<String, dynamic>> images;
  final Function(Map<String, dynamic>)? onImageTap;
  final Function? onRefresh;
  final int crossAxisCount;
  final bool showDetails;

  const ImageGrid({
    Key? key,
    required this.images,
    this.onImageTap,
    this.onRefresh,
    this.crossAxisCount = 2,
    this.showDetails = true,
  }) : super(key: key);

  @override
  State<ImageGrid> createState() => _ImageGridState();
}

class _ImageGridState extends State<ImageGrid> {
  @override
  Widget build(BuildContext context) {
    if (widget.images.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.image_not_supported, size: 64, color: Colors.grey[400]),
            SizedBox(height: 16),
            Text(
              'No images found',
              style: TextStyle(fontSize: 18, color: Colors.grey[600]),
            ),
            SizedBox(height: 8),
            Text(
              'Upload a plant image to begin',
              style: TextStyle(fontSize: 14, color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        if (widget.onRefresh != null) {
          await widget.onRefresh!();
        }
      },
      child: GridView.builder(
        padding: EdgeInsets.all(8),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: widget.crossAxisCount,
          childAspectRatio: 0.8,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
        ),
        itemCount: widget.images.length,
        itemBuilder: (context, index) {
          final imageData = widget.images[index];
          return ImageCard(
            imageData: imageData,
            onTap:
                widget.onImageTap != null
                    ? () => widget.onImageTap!(imageData)
                    : null,
            onDelete: () {
              // Refresh the list after deletion
              if (widget.onRefresh != null) {
                widget.onRefresh!();
              }
            },
            showDetails: widget.showDetails,
          );
        },
      ),
    );
  }
}
