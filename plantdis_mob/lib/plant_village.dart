import 'dart:typed_data';
import 'dart:io';
import 'package:tflite/tflite.dart';
import 'package:image/image.dart' as img;

class PlantVillageModel {
  // Path to the TFLite model and labels file
  static const String modelPath = "assets/plant_disease_model.tflite";
  static const String labelsPath = "assets/labels_village.txt";
  static const int inputSize = 224; // Input size for the model

  // Function to load the TFLite model
  Future<void> loadModel() async {
    try {
      // Loading the TFLite model and labels
      await Tflite.loadModel(
        model: modelPath,
        labels: labelsPath,
      );
      print('Plant Village Model loaded successfully');
    } catch (e) {
      print('Error loading Plant Village model: $e');
    }
  }

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
      imageMean: 0, // Mean normalization value
      imageStd: 255, // Standard deviation normalization value
    );

    // Checking the output and returning the predicted label with confidence
    if (output != null && output.isNotEmpty) {
      String predictedLabel = output[0]['label'];
      double confidence = output[0]['confidence'] * 100; // Convert to percentage
      return ['$predictedLabel (${confidence.toStringAsFixed(2)}%)'];
    } else {
      return ['un_known'];
    }
  }

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
    // Split the result string at the first underscore
    int firstUnderscore = rawResult.indexOf('_');
    if (firstUnderscore == -1) {
      // If there is no underscore, return an error message
      return 'Sorry, please try another plant photo.';
    }

    String plant = rawResult.substring(0, firstUnderscore);
    String remaining = rawResult.substring(firstUnderscore + 1);

    // Handle the case for Background_without_leaves
    if (rawResult == 'Background_without_leaves') {
      return 'Sorry, the photo does not contain leaves. Please try another plant photo.';
    }

    // Handle the healthy case
    if (remaining == 'healthy') {
      return 'The plant is $plant, and it is healthy.';
    } else {
      // Replace underscores in the disease part with spaces
      String disease = remaining.replaceAll('_', ' ');
      return 'The plant is $plant, and the disease is $disease.';
    }
  }

}
