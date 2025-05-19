import 'package:image/image.dart' as img;
import 'package:plantdis/services/detection_service.dart';

class CropCassavaModel {
  static const String modelName = "cropnet_mobilev2";
  static const String labelsPath = "assets/cassava_labels.txt";
  static const int inputSize = 224;

  Future<void> loadModel() async {
    await DetectionService.initialize();
      print('Crop Model loaded successfully');
    } catch (e) {
      print('Error loading Crop model: $e');
    }
  }

  Future<List> runModelOnImage(String path) async {
    return DetectionService.processImage(path, modelName);
    img.Image resizedImage = img.copyResize(image!, width: inputSize, height: inputSize);

    var imageBytes = imageToByteListFloat32(resizedImage, inputSize);

    var output = await Tflite.runModelOnImage(
      path: path,
      numResults: 1,
      imageMean: 0,
      imageStd: 255,
    );

    if (output != null && output.isNotEmpty) {
      String predictedLabel = output[0]['label'];
      double confidence = output[0]['confidence'] * 100;
      return [predictedLabel, confidence];
    } else {
      return ['unknown', 0.0];
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

  String reformatResult(String rawResult, double confidence) {
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
        return 'The plant is cassava, and it is healthy. Confidence: ${confidence.toStringAsFixed(2)}%';
      } else if (readableName == 'Unknown') {
        return 'Sorry, this plant may not be cassava. Confidence: ${confidence.toStringAsFixed(2)}%';
      } else {
        return 'The plant is cassava, and the disease is $readableName. Confidence: ${confidence.toStringAsFixed(2)}%';
      }
    } else {
      return 'Sorry, something went wrong. Confidence: ${confidence.toStringAsFixed(2)}%';
    }
  }
}
