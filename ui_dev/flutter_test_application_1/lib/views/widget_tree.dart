import 'package:camera/camera.dart';
import 'package:cross_file_image/cross_file_image.dart';
import 'package:easy_image_viewer/easy_image_viewer.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_test_application_1/services/database_service.dart';

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
        imageQuality: 85, // 压缩一点，兼顾传输速度
      );

      if (pickedFile == null) {
        // 用户取消了
        return;
      }

      if (!mounted) return;

      setState(() {
        xfile = pickedFile;
      });

      final result = await database.uploadImage(xfile!);

      if (!mounted) return;

      showImageViewer(
        context,
        Image(image: XFileImage(xfile!)).image,
        swipeDismissible: true,
        doubleTapZoomable: true,
        onViewerDismissed: () {},
      );

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => SegmentPage(
            imgSrc: result['downloadUrl'],
            id: result['imageId'],
            plantId: result['plantId'],
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      _showErrorDialog(
        'Error picking image: $e\n\nPlease make sure you have granted gallery access (Mobile) or file selection (Web) permissions.',
      );
    }
  }


  Future<void> _showCamera() async {
    try {
      // Check if camera is allowed on this connection
      // if (kIsWeb && !WebUtils.isCameraAllowed) {
      //   _showErrorDialog(
      //     'Camera access requires HTTPS or localhost. Please access the app using a secure connection.',
      //   );
      //   return;
      // }

      // // Request camera permission first if on web
      // if (kIsWeb) {
      //   try {
      //     await WebUtils.requestCameraPermission();
      //   } catch (e) {
      //     _showErrorDialog(
      //       'Camera permission denied. Please allow camera access in your browser settings.',
      //     );
      //     return;
      //   }
      // }

      final cameras = await availableCameras();

      if (cameras.isEmpty) {
        _showErrorDialog('No cameras found on your device');
        return;
      }

      // Try to get the back camera first, fall back to the first available camera
      final camera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );

      if (!mounted) return;

      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => TakePicturePage(camera: camera),
        ),
      );

      if (result != null && mounted) {
        setState(() {
          xfile = result as XFile;
          showImageViewer(
            context,
            Image(image: XFileImage(xfile!)).image,
            swipeDismissible: true,
            doubleTapZoomable: true,
            onViewerDismissed: () {},
          );
          database.uploadImage(xfile!);
        });
      }
    } catch (e) {
      if (!mounted) return;
      _showErrorDialog(
        'Error accessing camera: $e\n\nPlease make sure you have granted camera permissions and are using HTTPS.',
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
