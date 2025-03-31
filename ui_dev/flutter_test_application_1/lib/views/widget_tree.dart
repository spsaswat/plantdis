import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_test_application_1/services/database_service.dart';
import 'package:flutter_test_application_1/views/pages/chat_page.dart';
import 'package:flutter_test_application_1/utils/web_utils.dart';
import 'package:flutter_test_application_1/views/widgets/appbar_widget.dart';
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
          builder: (BuildContext context, dynamic selectedPage, Widget? child) {
            return selectedPage == 0
                ? FloatingActionButton(
                  child: Icon(Icons.add_a_photo_rounded),
                  onPressed: () => _showCamera(),
                )
                : SizedBox();
          },
        ),

        bottomNavigationBar: NavBarWidget(),
      ),
    );
  }

  Future<void> _showCamera() async {
    try {
      // Check if camera is allowed on this connection
      if (kIsWeb && !WebUtils.isCameraAllowed) {
        _showErrorDialog(
          'Camera access requires HTTPS or localhost. Please access the app using a secure connection.',
        );
        return;
      }

      // Get available cameras
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

      final xfile = await Navigator.of(context).push<XFile>(
        MaterialPageRoute(
          builder: (context) => TakePicturePage(camera: camera),
        ),
      );

      if (xfile != null) {
        setState(() {
          this.xfile = xfile;
          database.uploadImage(xfile);
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
