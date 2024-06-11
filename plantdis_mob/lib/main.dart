import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tflite/tflite.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:image/image.dart' as img;
import 'dart:io';
// import 'package:flutter_native_image/flutter_native_image.dart';

void main() {
  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        appBar: AppBar(
          title: const Text('PlantDis'),
          backgroundColor: Colors.green[600],
        ),
        body: Center(child: MyImagePicker()),
      ),
      builder: EasyLoading.init(),
    ),
  );
}

class MyImagePicker extends StatefulWidget {
  @override
  MyImagePickerState createState() => MyImagePickerState();
}

class MyImagePickerState extends State {
  var _image;
  var path_1;
  var result;

  Future imageFromCamera() async {
    final ImagePicker _picker = ImagePicker();
    final XFile? image = await _picker.pickImage(source: ImageSource.camera);

    setState(() {
      if (image != null) {
        _image = File(image.path);
        path_1 = image.path;
      }
    });
  }

  Future imageFromGallery() async {
    final ImagePicker _picker = ImagePicker();
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);

    setState(() {
      if (image != null) {
        _image = File(image.path);
        path_1 = image.path;
      }
    });
  }

  Uint8List imageToByteListFloat32(
      img.Image image, int inputSize, double mean, double std) {
    var convertedBytes = Float32List(1 * inputSize * inputSize * 3);
    var buffer = Float32List.view(convertedBytes.buffer);
    int pixelIndex = 0;
    for (var i = 0; i < inputSize; i++) {
      for (var j = 0; j < inputSize; j++) {
        var pixel = image.getPixel(j, i);
        buffer[pixelIndex++] = (img.getRed(pixel) - mean) / std;
        buffer[pixelIndex++] = (img.getGreen(pixel) - mean) / std;
        buffer[pixelIndex++] = (img.getBlue(pixel) - mean) / std;
      }
    }
    return convertedBytes.buffer.asUint8List();
  }

  Future diagnoseLeaf() async {
    if (path_1 != null) {
      EasyLoading.instance
        ..indicatorType = EasyLoadingIndicatorType.fadingGrid
        ..indicatorSize = 35.0
        ..radius = 6.0
        ..userInteractions = false
        ..dismissOnTap = false;

      EasyLoading.show(status: 'loading...');

      // // converting the to Image format from the file format(for model on bin)
      // img.Image? oriImage = img.decodeImage(_image.readAsBytesSync());
      // img.Image resizedImage =
      //     img.copyResize(oriImage!, height: 256, width: 256);

      // // if required try integrating cropping
      // ImageProperties properties =
      //     await FlutterNativeImage.getImageProperties(_image.path);
      // File compressedFile;
      // if (properties.height != 256 || properties.width != 256) {
      //   compressedFile = await FlutterNativeImage.compressImage(
      //       _image.path,
      //       quality: 95,
      //       targetWidth: 256,
      //       targetHeight: 256);
      // }

      await Tflite.loadModel(
          model: "assets/pd_tfl_dn_6.tflite", labels: "assets/labels.txt");

      // // good for using after proccessing the image but slows down if image is of high resolution
      // var output = await Tflite.runModelOnBinary(
      //     binary: imageToByteListFloat32(resizedImage, 256, 0.0, 255.0),
      //     numResults: 1,
      //     threshold: 0.80);

      var output = await Tflite.runModelOnImage(
        path: path_1,
        numResults: 1,
        threshold: 0.89,
        imageMean: 0,
        imageStd: 255,
      );

      EasyLoading.dismiss();

      setState(() {
        if (output != null && output.isNotEmpty) {
          result = output[0]['label'].toString();
        } else if (output != null && output.isEmpty) {
          result = 'Sorry! I could not identify anything';
        } else {
          result = "Sorry! My Model Failed";
        }
      });
    } else {
      EasyLoading.instance
        ..displayDuration = const Duration(milliseconds: 2000)
        ..userInteractions = false
        ..dismissOnTap = true;
      EasyLoading.showToast('Please select or capture image');
    }
  }

  @override
  Widget build(BuildContext context) {
    final ButtonStyle style = ElevatedButton.styleFrom(
        // textStyle: const TextStyle(color: Color(0xff000000)),
        foregroundColor: const Color(0xff000000), backgroundColor: const Color(0xffF8DC27), shadowColor: const Color(0xffF8DC27).withOpacity(0.4));
    return Scaffold(
        backgroundColor: Colors.lightGreenAccent,
        body: SafeArea(
          child: Center(
              child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                _image == null
                    ? const Text('No image selected.')
                    : Image.file(_image,
                        width: 300, height: 200, fit: BoxFit.cover),
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
                    )),
                result == null ? const Text('Result') : Text(result)
              ])),
        ));
  }
}
