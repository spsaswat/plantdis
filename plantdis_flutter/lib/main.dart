import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

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
  String? path;
  String fName = "";
  int fSize = 0;

  imageFromCamera() {}

  imageFromGallery() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom, allowedExtensions: ['jpg', 'png', 'jpeg']);

    if (result != null) {
      fileUri = result.files.first;
      // // ignore: avoid_print
      // print(file.name);
      // // ignore: avoid_print
      // print(file.bytes);
      // // ignore: avoid_print
      // print(file.size);
      // // ignore: avoid_print
      // print(file.extension);
      // ignore: avoid_print
      print(fileUri.path);

      setState(() {
        fName = fileUri.name;
        fSize = fileUri.size;

        // path = file.path;
      });
    } else {
      // User canceled the picker
    }
  }

  diagnoseLeaf() async {}

  @override
  Widget build(BuildContext context) {
    final ButtonStyle style = ElevatedButton.styleFrom(
        // textStyle: const TextStyle(color: Color(0xff000000)),
        shadowColor: const Color(0xffF8DC27).withOpacity(0.4),
        onPrimary: const Color(0xff000000),
        primary: const Color(0xffF8DC27));
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
                      onPressed: () => diagnoseLeaf(),
                      child: const Text('Diagnose'),
                      style: style,
                      // textColor: const Color(0xff000000),
                      // color: const Color(0xffF8DC27),
                      // padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                    )),
              ])),
        ));
  }
}
