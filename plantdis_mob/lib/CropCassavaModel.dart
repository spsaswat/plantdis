import 'dart:typed_data';
import 'dart:io';
import 'package:tflite/tflite.dart';
import 'package:image/image.dart' as img;

class CropCassavaModel {
  static const String modelPath = "assets/cropnet_mobilev2.tflite";
  static const String labelsPath = "assets/cassava_labels.txt";
  static const int inputSize = 224;

  Future<void> loadModel() async {
    try {
      await Tflite.loadModel(
        model: modelPath,
        labels: labelsPath,
      );
      print('Crop Model loaded successfully');
    } catch (e) {
      print('Error loading Crop model: $e');
    }
  }

  Future<List?> runModelOnImage(String path) async {
    File imageFile = File(path);
    img.Image? image = img.decodeImage(imageFile.readAsBytesSync());
    img.Image resizedImage = img.copyResize(image!, width: inputSize, height: inputSize);

    // 预处理图像
    var imageBytes = imageToByteListFloat32(resizedImage, inputSize);

    // 分类
    var output = await Tflite.runModelOnImage(
      path: path,
      numResults: 1,
      threshold: 0.8,
      imageMean: 0,
      imageStd: 255,
    );

    if (output != null && output.isNotEmpty) {
      String predictedLabel = output[0]['label'];
      return [predictedLabel];
    } else {
      return ['unknown'];
    }
  }

  Uint8List imageToByteListFloat32(img.Image image, int inputSize) {
    var convertedBytes = Float32List(1 * inputSize * inputSize * 3);
    var buffer = Float32List.view(convertedBytes.buffer);
    int pixelIndex = 0;
    for (var i = 0; i < inputSize; i++) {
      for (var j = 0; j < inputSize; j++) {
        var pixel = image.getPixel(j, i);
        buffer[pixelIndex++] = img.getRed(pixel) / 255.0;
        buffer[pixelIndex++] = img.getGreen(pixel) / 255.0;
        buffer[pixelIndex++] = img.getBlue(pixel) / 255.0;
      }
    }
    return convertedBytes.buffer.asUint8List();
  }

  String reformatResult(String rawResult) {
    Map<String, String> nameMap = {
      'cmd': 'Mosaic Disease',
      'cbb': 'Bacterial Blight',
      'cgm': 'Green Mite',
      'cbsd': 'Brown Streak Disease',
      'healthy': 'Healthy',
      'unknown': 'Unknown'
    };

    if (nameMap.containsKey(rawResult)) {
      String? readableName = nameMap[rawResult];
      if (readableName == 'Healthy') {
        return 'The plant is cassava, and it is healthy.';
      } else {
        return 'The plant is cassava, and the disease is $readableName.';
      }
    } else {
      return 'The plant is cassava, and the disease is unknown.';
    }
  }
}
