import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test_application_1/services/database_service.dart';
import 'package:flutter_test_application_1/services/plant_service.dart';

import 'package:flutter_test_application_1/views/pages/chat_page.dart';
import 'package:flutter_test_application_1/views/pages/segment_page.dart';
// import 'package:flutter_test_application_1/utils/web_utils.dart';
import 'package:flutter_test_application_1/views/widgets/appbar_widget.dart';
import 'package:image_picker/image_picker.dart';
import 'pages/take_picture_page.dart';
import 'widgets/navbar_widget.dart';

import '../data/notifiers.dart';
import 'widgets/drawer_widget.dart';

import 'pages/home_page.dart';
import 'pages/profile_page.dart';

List<Widget> pages = [HomePage(), ChatPage(), ProfilePage()];

class WidgetTree extends StatefulWidget {
  const WidgetTree({super.key});

  @override
  State<WidgetTree> createState() => _WidgetTreeState();
}

class _WidgetTreeState extends State<WidgetTree> {
  XFile? xfile;
  final PlantService _plantService = PlantService();

  DatabaseService database = DatabaseService();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        appBar: AppbarWidget(),

        drawer: DrawerWidget(),

        body: ValueListenableBuilder(
          valueListenable: selectedPageNotifier,
          builder: (BuildContext context, dynamic selectedPage, Widget? child) {
            return pages.elementAt(selectedPage);
          },
        ),

        floatingActionButton: ValueListenableBuilder(
          valueListenable: selectedPageNotifier,
          builder: (context, selectedPage, child) {
            return selectedPage == 0
                ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FloatingActionButton(
                      heroTag: 'upload_image',
                      child: Icon(Icons.photo_library),
                      tooltip: 'Upload from Gallery',
                      onPressed: () => _pickImageFromGallery(),
                    ),
                    SizedBox(height: 10),
                    FloatingActionButton(
                      heroTag: 'take_picture',
                      child: Icon(Icons.add_a_photo),
                      tooltip: 'Take Picture',
                      onPressed: () => _showCamera(),
                    ),
                  ],
                )
                : SizedBox();
          },
        ),

        bottomNavigationBar: NavBarWidget(),
      ),
    );
  }

  Future<void> _pickImageFromGallery() async {
    try {
      final ImagePicker picker = ImagePicker();

      final XFile? pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (pickedFile == null) return;
      if (!mounted) return;

      setState(() {
        xfile = pickedFile;
      });

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      try {
        final result = await _plantService.uploadAndAnalyzeImage(
          image: pickedFile,
          notes: 'Uploaded from gallery',
        );

        if (!mounted) return;
        Navigator.of(context).pop();

        if (result.containsKey('plantId')) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder:
                  (context) => SegmentPage(
                    imgSrc: result['downloadUrl'],
                    id: result['imageId'],
                    plantId: result['plantId'],
                  ),
            ),
          );
        } else {
          _showErrorDialog(
            'Upload and analysis completed but result was unexpected.',
          );
        }
      } catch (e) {
        if (!mounted) return;
        Navigator.of(context).pop();
        _showErrorDialog(
          'Error during upload/analysis: ${e.toString()}\n\nPlease try again.',
        );
      }
    } catch (e) {
      if (!mounted) return;
      _showErrorDialog(
        'Error picking image: ${e.toString()}\n\nPlease check permissions.',
      );
    }
  }

  Future<void> _showCamera() async {
    try {
      final cameras = await availableCameras();

      if (cameras.isEmpty) {
        _showErrorDialog('No cameras found on your device');
        return;
      }

      final camera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );

      if (!mounted) return;

      final XFile? capturedImageFile = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => TakePicturePage(camera: camera),
        ),
      );

      if (capturedImageFile == null) return;
      if (!mounted) return;

      setState(() {
        xfile = capturedImageFile;
      });

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      try {
        final result = await _plantService.uploadAndAnalyzeImage(
          image: capturedImageFile,
          notes: 'Captured from camera',
        );

        if (!mounted) return;
        Navigator.of(context).pop();

        if (result.containsKey('plantId')) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder:
                  (context) => SegmentPage(
                    imgSrc: result['downloadUrl'],
                    id: result['imageId'],
                    plantId: result['plantId'],
                  ),
            ),
          );
        } else {
          _showErrorDialog(
            'Capture and analysis completed but result was unexpected.',
          );
        }
      } catch (e) {
        if (!mounted) return;
        Navigator.of(context).pop();
        _showErrorDialog(
          'Error during capture/analysis: ${e.toString()}\n\nPlease try again.',
        );
      }
    } catch (e) {
      if (!mounted) return;
      _showErrorDialog(
        'Error accessing camera: ${e.toString()}\n\nPlease ensure permissions are granted and using HTTPS if on web.',
      );
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('Camera Error'),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text('OK'),
              ),
            ],
          ),
    );
  }
}
