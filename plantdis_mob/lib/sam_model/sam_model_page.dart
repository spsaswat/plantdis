import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_vision/flutter_vision.dart';
import 'package:image/image.dart' as img;


class SamModelPage extends StatefulWidget {
  @override
  _SamModelPageState createState() => _SamModelPageState();
}

class _SamModelPageState extends State<SamModelPage> {
  FlutterVision _vision = FlutterVision();
  Uint8List? _imageData;
  Uint8List? _maskImage;  // Store the mask image for display
  int _imageWidth = 640;  // Set to 640 as the target size for input
  int _imageHeight = 640;
  bool _isModelLoaded = false;
  List<Map<String, dynamic>>? _segmentationResult;
  int _currentMaskIndex = 0;  // Index for the mask currently being displayed

  @override
  void initState() {
    super.initState();
    _loadModel();
  }

  Future<void> _loadModel() async {
    try {
      print('Loading YOLOv8 Segmentation model...');

      // Load the TFLite YOLOv8 segmentation model
      await _vision.loadYoloModel(
        labels: 'assets/seglabel.txt',  // Label file path
        modelPath: 'assets/segyolov8_1.tflite',  // TFLite model path
        modelVersion: 'yolov8',  // Version of YOLO model (v8)
        quantization: false,  // Set to false if the model is not quantized
        numThreads: 1,  // Number of threads to use
        useGpu: false,  // Set to true to use GPU acceleration
      );

      setState(() {
        _isModelLoaded = true;
      });

      print('Model loaded successfully');
    } catch (e) {
      print('Error loading model: $e');
    }
  }

  // Select an image from the gallery
  Future<void> _pickImage() async {
    final ImagePicker _picker = ImagePicker();
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);

    if (image != null) {
      final Uint8List imageData = await image.readAsBytes();
      final img.Image? decodedImage = img.decodeImage(imageData);

      if (decodedImage != null) {
        // Resize the image to 640x640
        final img.Image resizedImage = img.copyResize(decodedImage, width: 640, height: 640);

        // Convert image to Float32List
        final Float32List normalizedImage = _convertImageToFloat32List(resizedImage);

        setState(() {
          _imageData = Uint8List.fromList(img.encodePng(resizedImage));  // Display the resized image
          _imageWidth = resizedImage.width;
          _imageHeight = resizedImage.height;
        });

        print('Image picked and resized to 640x640');
      }
    }
  }

  // Convert image to Float32List
  Float32List _convertImageToFloat32List(img.Image image) {
    final Float32List float32List = Float32List(image.width * image.height * 3);
    int index = 0;

    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        final pixel = image.getPixel(x, y);
        float32List[index++] = img.getRed(pixel) / 255.0;    // Normalize to [0,1]
        float32List[index++] = img.getGreen(pixel) / 255.0;
        float32List[index++] = img.getBlue(pixel) / 255.0;
      }
    }
    return float32List;
  }

  // Run segmentation model
  Future<void> _runModel() async {
    if (!_isModelLoaded) {
      print('Model is not loaded');
      return;
    }

    if (_imageData == null) {
      print('No image selected');
      return;
    }

    try {
      print('Running segmentation model...');

      // Run segmentation using the model with Float32 input
      final result = await _vision.yoloOnImage(
        bytesList: _convertImageToUint8List(_imageData!),  // Convert to Uint8List
        imageHeight: _imageHeight,
        imageWidth: _imageWidth,
        iouThreshold: 0,  // Set the IoU threshold
        confThreshold: 0,  // Set confidence threshold
        classThreshold: 0,  // Set class threshold
      );

      setState(() {
        _segmentationResult = result;
        _currentMaskIndex = 0;  // Reset mask index
      });

      // Display first mask
      _displayMask(0);
      print('Segmentation result: $result');
    } catch (e) {
      print('Error during segmentation: $e');
    }
  }

  void _displayMask(int index) {
    if (_segmentationResult != null && _segmentationResult!.isNotEmpty && index < _segmentationResult!.length) {
      final mask = _segmentationResult![index]['mask'];

      if (mask != null && mask is List<int>) {
        // Convert mask to Uint8List and display
        _maskImage = Uint8List.fromList(mask);
        setState(() {});
        print('Mask displayed for object $index');
      } else {
        print('Invalid mask data for object $index');
      }
    } else {
      print('No mask to display for index $index');
    }
  }


  // Show the next segmentation mask
  void _showNextMask() {
    if (_segmentationResult != null && _segmentationResult!.isNotEmpty) {
      _currentMaskIndex = (_currentMaskIndex + 1) % _segmentationResult!.length;
      _displayMask(_currentMaskIndex);
    }
  }

  @override
  void dispose() {
    _vision.closeYoloModel();  // Release resources
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('YoloV8 Segmentation with TFLite'),
      ),
      body: Column(
        children: [
          _imageData == null
              ? Text('No image selected.')
              : Image.memory(
            _imageData!,
            fit: BoxFit.cover,
          ),
          ElevatedButton(
            onPressed: _pickImage,
            child: Text('Pick Image'),
          ),
          ElevatedButton(
            onPressed: _isModelLoaded ? _runModel : null,
            child: Text('Run Segmentation'),
          ),
          _maskImage != null
              ? Image.memory(_maskImage!)  // Display segmentation mask
              : Text('No mask to display.'),
          ElevatedButton(
            onPressed: _showNextMask,
            child: Text('Show Next Mask'),  // Show next mask
          ),
        ],
      ),
    );
  }

  // Convert Float32List to Uint8List
  Uint8List _convertImageToUint8List(Uint8List imageData) {
    // Assuming the image is already normalized and resized to 640x640, we return the same data here.
    return imageData;
  }
}
