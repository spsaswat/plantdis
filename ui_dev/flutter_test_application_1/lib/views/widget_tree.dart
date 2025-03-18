import 'package:camera/camera.dart';
import 'package:cross_file_image/cross_file_image.dart';
import 'package:easy_image_viewer/easy_image_viewer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test_application_1/services/database_service.dart';
import 'package:flutter_test_application_1/views/widgets/appbar_widget.dart';
import 'pages/take_picture_page.dart';
import 'widgets/navbar_widget.dart';

import '../data/notifiers.dart';
import 'widgets/drawer_widget.dart';

import 'pages/home_page.dart';
import 'pages/profile_page.dart';

List<Widget> pages = [HomePage(), ProfilePage()];

class WidgetTree extends StatefulWidget {
  WidgetTree({super.key});

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

        floatingActionButton: FloatingActionButton(
          child: Icon(Icons.add_a_photo_rounded),
          onPressed: () => _showCamera(),
        ),

        bottomNavigationBar: NavBarWidget(),
      ),
    );
  }

  void _showCamera() async {
    final cameras = await availableCameras();
    final camera = cameras.first;
    if (!mounted) return;
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => TakePicturePage(camera: camera)),
    );
    if (result != null) {
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
  }
}
