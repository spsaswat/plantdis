import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'package:flutter_easyloading/flutter_easyloading.dart';

void main() {
  runApp(
    MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('PlantDis'),
          backgroundColor: Colors.green[600],
        ),
        body: const Center(child: MyImagePicker()),
      ),
      builder: EasyLoading.init(),
    ),
  );
}

class MyImagePicker extends StatefulWidget {
  const MyImagePicker({Key? key}) : super(key: key);

  @override
  MyImagePickerState createState() => MyImagePickerState();
}

class MyImagePickerState extends State {
  late PlatformFile fileUri;
  String path = '';
  String fName = "";
  int fSize = 0;

  imageFromCamera() async {
    EasyLoading.instance
      ..displayDuration = const Duration(milliseconds: 2000)
      ..userInteractions = false
      ..dismissOnTap = true;
    EasyLoading.showToast('Camera Not yet set');
  }

  imageFromGallery() async {
    EasyLoading.instance
      ..indicatorType = EasyLoadingIndicatorType.fadingCube
      ..indicatorSize = 50.0
      ..radius = 13.0
      ..userInteractions = false
      ..dismissOnTap = false;

    EasyLoading.show(status: 'loading...');
    FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'png', 'jpeg', 'JPG', 'PNG', 'JPEG']);

    EasyLoading.dismiss();
    if (result != null) {
      fileUri = result.files.first;
      // ignore: avoid_print
      print(fileUri.path);

      setState(() {
        fName = fileUri.name;
        fSize = fileUri.size;

        path = fileUri.path.toString();
      });
    } else {
      // User canceled the picker
    }
  }

  demoLeaf() async {
    EasyLoading.instance
      ..indicatorType = EasyLoadingIndicatorType.fadingGrid
      ..indicatorSize = 50.0
      ..radius = 13.0
      ..userInteractions = false
      ..dismissOnTap = false;

    EasyLoading.show(status: 'loading... \n may take 4 mins');

    // var result = await Process.run('ml', ['demo', 'plantdis']);

    await Process.run('ml', ['demo', 'plantdis']);
    // ignore: avoid_print
    // print(result);
    EasyLoading.dismiss();
  }

  diagnoseLeaf() async {
    EasyLoading.instance
      ..indicatorType = EasyLoadingIndicatorType.fadingGrid
      ..indicatorSize = 50.0
      ..radius = 13.0
      ..userInteractions = false
      ..dismissOnTap = false;

    if (path == '') {
      EasyLoading.instance
        ..displayDuration = const Duration(milliseconds: 2000)
        ..userInteractions = false
        ..dismissOnTap = true;
      EasyLoading.showToast('Please select or capture image');
    }
    EasyLoading.show(status: 'loading... \n may take 4 mins');

    // var result = await Process.run('ml', ['demo', 'plantdis']);

    await Process.run('ml', ['diagnose', 'plantdis', '-v', path]);
    // ignore: avoid_print
    // print(result);
    EasyLoading.dismiss();
  }

  @override
  Widget build(BuildContext context) {
    final ButtonStyle style = ElevatedButton.styleFrom(
        // textStyle: const TextStyle(color: Color(0xff000000)),
        foregroundColor: const Color(0xff000000), shadowColor: const Color(0xffF8DC27).withOpacity(0.4), backgroundColor: const Color(0xffF8DC27));
    return Scaffold(
        backgroundColor: Colors.lightGreenAccent,
        body: SafeArea(
          child: Center(
              child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                if (fSize == 0)
                  const Text('No image selected.')
                else
                  Text('Image is selected is ' + fName),
                Container(
                    margin: const EdgeInsets.fromLTRB(0, 30, 0, 20),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: <Widget>[
                        IconButton(
                          icon: const Icon(Icons.camera_alt),
                          color: const Color(0xffF8DC27),
                          onPressed: () => imageFromCamera(),
                        ),
                        const SizedBox(height: 20),
                        IconButton(
                          icon: const Icon(Icons.collections),
                          color: const Color(0xffF8DC27),
                          onPressed: () => imageFromGallery(),
                        ),
                      ],
                    )),
                Container(
                    margin: const EdgeInsets.fromLTRB(0, 30, 0, 20),
                    child: ElevatedButton(
                      onPressed: () => demoLeaf(),
                      child: const Text('Demo'),
                      style: style,
                    )),
                Container(
                    margin: const EdgeInsets.fromLTRB(0, 30, 0, 20),
                    child: ElevatedButton(
                      onPressed: () => diagnoseLeaf(),
                      child: const Text('Diagnose'),
                      style: style,
                    )),
              ])),
        ));
  }
}
