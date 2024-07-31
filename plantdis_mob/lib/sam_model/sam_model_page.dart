import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:onnxruntime/onnxruntime.dart';
import 'sam_model.dart'; // Import the SamModel class
import 'package:image/image.dart' as img;

class SamModelPage extends StatefulWidget {
  @override
  _SamModelPageState createState() => _SamModelPageState();
}

class _SamModelPageState extends State<SamModelPage> {
  SamModel _samModel = SamModel();
  Uint8List? _imageData;
  List<Offset> _points = [];
  final _pointLabels = <int>[];
  int? _imageWidth;
  int? _imageHeight;
  bool _isModelLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadModel();
  }

  Future<void> _loadModel() async {
    try {
      await _samModel.loadModel();
      setState(() {
        _isModelLoaded = true;
      });
      print('SAM Model loaded successfully');
    } catch (e) {
      print('Error loading SAM Model: $e');
    }
  }

  Future<void> _pickImage() async {
    final ImagePicker _picker = ImagePicker();
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);

    if (image != null) {
      final imageData = await image.readAsBytes();
      final img.Image? decodedImage = img.decodeImage(imageData);
      setState(() {
        _imageData = imageData;
        _imageWidth = decodedImage?.width;
        _imageHeight = decodedImage?.height;
      });
    }
  }

  Future<void> _runModel() async {
    if (!_isModelLoaded) {
      print('Model is not loaded');
      return;
    }

    if (_imageData == null || _points.isEmpty || _imageWidth == null || _imageHeight == null) {
      print('No image selected or no points selected');
      return;
    }

    // Prepare dummy data for other inputs, replace these with actual data as needed
    final imageEmbedding = Float32List.fromList(List.filled(256 * 64 * 64, 0.0)); // Replace with actual embedding data
    final pointCoords = Float32List(_points.length * 2);
    for (int i = 0; i < _points.length; i++) {
      pointCoords[i * 2] = _points[i].dx;
      pointCoords[i * 2 + 1] = _points[i].dy;
    }

    final pointLabels = Float32List.fromList(_pointLabels.map((e) => e.toDouble()).toList());
    final maskInput = Float32List.fromList(List.filled(1 * 256 * 256, 0.0)); // Replace with actual mask input data
    final hasMaskInput = Float32List.fromList([1.0]); // Replace with actual has mask input data
    final origImSize = Float32List.fromList([_imageWidth!.toDouble(), _imageHeight!.toDouble()]); // Use actual image width and height

    final results = await _samModel.runModel(_imageData!, pointCoords, pointLabels, maskInput, hasMaskInput, origImSize);
    print('Model run successfully, results: $results');
    // Process and display the results as needed
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('SAM Model Page'),
      ),
      body: Column(
        children: [
          _imageData == null
              ? Text('No image selected.')
              : GestureDetector(
            onTapDown: (details) {
              setState(() {
                _points.add(details.localPosition);
                _pointLabels.add(1); // Assume all points are foreground points
              });
            },
            child: Image.memory(
              _imageData!,
              fit: BoxFit.cover,
            ),
          ),
          ElevatedButton(
            onPressed: _pickImage,
            child: Text('Pick Image'),
          ),
          ElevatedButton(
            onPressed: _isModelLoaded ? _runModel : null,
            child: Text('Run Model'),
          ),
        ],
      ),
    );
  }
}
