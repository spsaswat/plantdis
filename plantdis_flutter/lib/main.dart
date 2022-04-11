import 'package:flutter/material.dart';

void main() {
  runApp(
    MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('PlantDis'),
          backgroundColor: Colors.green[600],
        ),
        body: Center(child: MyImagePicker()),
      ),
    ),
  );
}

class MyImagePicker extends StatefulWidget {
  @override
  MyImagePickerState createState() => MyImagePickerState();
}

class MyImagePickerState extends State {
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
                const Text('No image has been selected.'),
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

  diagnoseLeaf() {}

  imageFromCamera() {}

  imageFromGallery() {}
}
