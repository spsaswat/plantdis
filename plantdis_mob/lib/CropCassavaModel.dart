import 'dart:typed_data';
import 'dart:io';
import 'package:tflite/tflite.dart';
import 'package:image/image.dart' as img;

class CropCassavaModel {
  // Path to the TFLite model and labels file
  static const String modelPath = "assets/cropnet_mobilev2.tflite";
  static const String labelsPath = "assets/cassava_labels.txt";
  static const int inputSize = 224; // Input size for the model

  // Function to load the TFLite model
  Future<void> loadModel() async {
    try {
      // Loading the TFLite model and labels
      await Tflite.loadModel(
        model: modelPath,
        labels: labelsPath,
      );
      print('Crop Model loaded successfully');
    } catch (e) {
      print('Error loading Crop model: $e');
    }
  }

  // Function to run the model on an image
  Future<List?> runModelOnImage(String path) async {
    // Reading the image file
    File imageFile = File(path);
    img.Image? image = img.decodeImage(imageFile.readAsBytesSync());
    // Resizing the image to the required input size
    img.Image resizedImage = img.copyResize(image!, width: inputSize, height: inputSize);

    // Preprocessing the image
    var imageBytes = imageToByteListFloat32(resizedImage, inputSize);

    // Running the model on the preprocessed image
    var output = await Tflite.runModelOnImage(
      path: path,
      numResults: 1, // Getting the top result
      threshold: 0.8, // Minimum confidence threshold
      imageMean: 0, // Mean normalization value
      imageStd: 255, // Standard deviation normalization value
    );

    // Checking the output and returning the predicted label
    if (output != null && output.isNotEmpty) {
      String predictedLabel = output[0]['label'];
      return [predictedLabel];
    } else {
      return ['unknown'];
    }
  }

  // Function to convert the image to a byte list of Float32
  Uint8List imageToByteListFloat32(img.Image image, int inputSize) {
    var convertedBytes = Float32List(1 * inputSize * inputSize * 3);
    var buffer = Float32List.view(convertedBytes.buffer);
    int pixelIndex = 0;
    // Normalizing the pixel values to [0, 1]
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

  // Function to reformat the result from the model into a readable string
  String reformatResult(String rawResult) {
    // Mapping of model output labels to readable names
    Map<String, String> nameMap = {
      'cmd': 'Mosaic Disease',
      'cbb': 'Bacterial Blight',
      'cgm': 'Green Mite',
      'cbsd': 'Brown Streak Disease',
      'healthy': 'Healthy',
      'unknown': 'Unknown'
    };

    // Checking if the raw result is in the name map
    if (nameMap.containsKey(rawResult)) {
      String? readableName = nameMap[rawResult];
      // Returning the appropriate message based on the readable name
      if (readableName == 'Healthy') {
        return 'The plant is cassava, and it is healthy.';
      } else if (readableName == 'Unknown'){
        return 'Sorry, this plant may not be cassava.';
      } else {
        return 'The plant is cassava, and the disease is $readableName.';
      }
    } else {
      return 'Sorry, something went wrong';
    }
  }
}
