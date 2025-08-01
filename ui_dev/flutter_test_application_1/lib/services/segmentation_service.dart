import 'dart:io';

import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/foundation.dart';      // kDebugMode
import 'package:image/image.dart' as img;     // For image processing
import 'package:onnxruntime/onnxruntime.dart'; // ONNX Runtime
import 'dart:ui' as ui;

/// Singleton service for segmentation model inference.
/// This service handles loading the ONNX model, running inference, 
/// and processing the output masks.
/// It uses the ONNX Runtime for Flutter to perform inference on the model.
/// The model is expected to be a Mask R-CNN model for leaf segmentation.
class SegmentationService {
  // --- Singleton Pattern Start ---
  static final SegmentationService _instance = SegmentationService._internal();
  factory SegmentationService() => _instance;
  SegmentationService._internal();
  // --- Singleton Pattern End ---

  // ONNX model asset path
  static const String _modelAssetPath = 'assets/models/leaf_mask_rcnn.onnx';

  late OrtSessionOptions _sessionOptions;
  OrtSession? _session;

  bool _modelLoaded = false;
  bool _isLoadingModel = false;

  /// Check if the model is loaded
  bool get isModelLoaded => _modelLoaded;

  /// Store the list of masks
  List<List<List<double>>>? _rawMasks;
  List<List<List<double>>>? get rawMasks => _rawMasks; // Public getter

  /// Asynchronously load the ONNX model.
  Future<void> loadModel() async {
    print('[SegmentationService] >> loadModel() ENTRY');
    if (_modelLoaded) {
      if (kDebugMode) print('[SegmentationService] Model already loaded.');
      return;
    }
    if (_isLoadingModel) {
      if (kDebugMode) print('[SegmentationService] Loading already in progress.');
      return;
    }
    _isLoadingModel = true;
    if (kDebugMode) print('[SegmentationService] Start loading segmentation model...');

    try {
      // 1. Initialize ONNX Runtime
      OrtEnv.instance.init();

      // 2. Set session options
      _sessionOptions = OrtSessionOptions();
      _sessionOptions.setIntraOpNumThreads(2);
      // _sessionOptions.addDelegate(GpuDelegateV2()); // GPU delegate if needed

      // 3. Load the model from assets
      final modelData = await rootBundle.load(_modelAssetPath);
      _session = OrtSession.fromBuffer(
        modelData.buffer.asUint8List(),
        _sessionOptions,
      );

      _modelLoaded = true;
      if (kDebugMode) print('[SegmentationService] Model loaded successfully.');
    } catch (e, st) {
      if (kDebugMode) {
        print('[SegmentationService] Error loading model: $e');
        print(st);
      }
      _modelLoaded = false;
    } finally {
      _isLoadingModel = false;
    }
  }

  /// Convert UI image to normalized float tensor [range 0.0 - 1.0].
  Future<List<double>> imageToFloatTensor(ui.Image img) async {
    // Get raw RGBA bytes from image.
    final bd = await img.toByteData(format: ui.ImageByteFormat.rawRgba);
    final rgba = Uint8List.view(bd!.buffer);

    // Separate color channels and normalize to [0,1].
    final r = <double>[], g = <double>[], b = <double>[];
    for (int i = 0; i < rgba.length; i += 4) {
      r.add(rgba[i] / 255.0);
      g.add(rgba[i + 1] / 255.0);
      b.add(rgba[i + 2] / 255.0);
      // Skip alpha channel at rgba[i + 3].
    }
    // Concatenate channel data in RGB order.
    return [...r, ...g, ...b];
  }

  Future<File> _generateUnionMask(List<List<List<double>>> rawMasks, img.Image decoded) async {
    final int Hm = rawMasks[0].length;
    final int Wm = rawMasks[0][0].length;

    final union = List.generate(Hm, (_) => List<bool>.filled(Wm, false));
    for (var m2d in rawMasks) {
      for (int y = 0; y < Hm; y++) {
        for (int x = 0; x < Wm; x++) {
          if (m2d[y][x] > 0.5) union[y][x] = true;
        }
      }
    }

    final img.Image maskImg = img.Image(width: Wm, height: Hm);
    for (int y = 0; y < Hm; y++) {
      for (int x = 0; x < Wm; x++) {
        if (union[y][x]) {
          maskImg.setPixel(x, y, decoded.getPixel(x, y));
        } else {
          maskImg.setPixelRgba(x, y, 0, 0, 0, 255);
        }
      }
    }

    final outFile = File('${Directory.systemTemp.path}/mask_union.png');
    await outFile.writeAsBytes(img.encodePng(maskImg));
    return outFile;
  }

  Future<List<File>> _generateSingleMasks(List<List<List<double>>> rawMasks, img.Image decoded) async {
    final int Hm = rawMasks[0].length;
    final int Wm = rawMasks[0][0].length;
    final List<File> maskFiles = [];

    for (int i = 0; i < rawMasks.length; i++) {
      final m2d = rawMasks[i];
      final img.Image maskImg = img.Image(width: Wm, height: Hm);

      for (int y = 0; y < Hm; y++) {
        for (int x = 0; x < Wm; x++) {
          if (m2d[y][x] > 0.5) {
            maskImg.setPixel(x, y, decoded.getPixel(x, y));
          } else {
            maskImg.setPixelRgba(x, y, 0, 0, 0, 255);
          }
        }
      }

      final outFile = File('${Directory.systemTemp.path}/mask_$i.png');
      await outFile.writeAsBytes(img.encodePng(maskImg));
      maskFiles.add(outFile);
    }

    return maskFiles;
  }


  /// Run the segmentation model on the input image file and return the output mask as a PNG file.
  Future<File> segment(File inputFile, {bool useUnionMask = true}) async {
    if (!_modelLoaded) {
      if (kDebugMode) print('[SegmentationService] Model not loaded, loading now...');
      await loadModel();
      if (!_modelLoaded || _session == null) {
        throw Exception('Segmentation model failed to load.');
      }
    }

    try {
      // 1. Read image from file and decode
      final Uint8List imgBytes = await inputFile.readAsBytes();
      final ui.Codec codec = await ui.instantiateImageCodec(imgBytes);
      final ui.FrameInfo frameInfo = await codec.getNextFrame();
      final ui.Image inputImage = frameInfo.image;
      final img.Image decoded = img.decodeImage(imgBytes)!;


      // 2. Get image height/width  
      final H = inputImage.height;
      final W = inputImage.width;

      // 3. Preprocess image to tensor.
      final floatData = await imageToFloatTensor(inputImage);
      final inputOrt = OrtValueTensor.createTensorWithDataList(
        Float32List.fromList(floatData),
        [1, 3, H, W],
      );


      // 3. Run inference
      final runOptions = OrtRunOptions();
      final outputs = _session!.run(runOptions, {'input': inputOrt});
      if (kDebugMode) print('=== SegService outputs count = ${outputs.length} ===');

      // 4. Extract masks from outputs
      // final raw = outputs[0]!.value as List; // Unused variable
      final masks4D = outputs[3]!.value as List;
      if (kDebugMode) print('[SegSvc] masks4D length = ${masks4D.length}');

      // 5. Convert masks to a list of 2D arrays
      final List<List<List<double>>> rawMasks = masks4D.map((det) {
        // det is a List of length 1, det[0] is the H×W 2D mask
        final mask2dDyn = (det as List)[0];
        return (mask2dDyn as List)
            .map<List<double>>((row) => (row as List).cast<double>())
            .toList();
      }).toList();
      _rawMasks = rawMasks;

      // 6. Post-process using union mask or individual masks
      if (useUnionMask) {
      final outFile = await _generateUnionMask(rawMasks, decoded);
      if (kDebugMode) {
        print('[SegmentationService] Union mask saved: ${outFile.path}');
      }
      // 7. Realase resources
      inputOrt.release();
      runOptions.release();

      // 8. Return the output mask file
      return outFile;
    } else {
      final outFiles = await _generateSingleMasks(rawMasks, decoded);
      if (outFiles.isEmpty) throw Exception('No mask files generated.');
      if (kDebugMode) {
        print('[SegmentationService] Individual mask files:');
        for (final f in outFiles) {
          print("  '${f.path}',");
        }
      }
      // 7. Realase resources
      inputOrt.release();
      runOptions.release();

      // 8. Return the output mask files
      return outFiles.first; // Return the first mask file for now
    }

    } catch (e, st) {
      if (kDebugMode) {
        print('[SegmentationService] Error during segmentation: $e');
        print(st);
      }
      rethrow;
    }
  }

  /// Realease resources and dispose of the session.
  void dispose() {
    _session?.release();
    OrtEnv.instance.release();
    if (kDebugMode) print('[SegmentationService] Resources disposed.');
  }
}