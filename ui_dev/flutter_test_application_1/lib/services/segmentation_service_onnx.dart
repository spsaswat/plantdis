import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:image/image.dart' as img;
import 'package:onnxruntime/onnxruntime.dart';
import 'package:flutter_test_application_1/utils/logger.dart';

/// ONNX 分割服务（基于之前的实现）
class OnnxSegmentationService {
  // 单例
  static final OnnxSegmentationService _instance =
      OnnxSegmentationService._internal();
  factory OnnxSegmentationService() => _instance;
  OnnxSegmentationService._internal();

  static const String _modelAssetPath = 'assets/models/leaf_mask_rcnn_v2.onnx';

  late OrtSessionOptions _sessionOptions;
  OrtSession? _session;
  bool _modelLoaded = false;
  bool _isLoadingModel = false;

  bool get isModelLoaded => _modelLoaded;

  Future<void> loadModel() async {
    if (_modelLoaded) return;
    if (_isLoadingModel) return;
    _isLoadingModel = true;
    try {
      OrtEnv.instance.init();
      _sessionOptions = OrtSessionOptions();
      _sessionOptions.setIntraOpNumThreads(2);
      final modelData = await rootBundle.load(_modelAssetPath);
      _session = OrtSession.fromBuffer(
        modelData.buffer.asUint8List(),
        _sessionOptions,
      );
      _modelLoaded = true;
      if (kDebugMode) logger.i('[OnnxSegmentationService] Model loaded.');
    } catch (e, st) {
      _modelLoaded = false;
      if (kDebugMode) {
        logger.e('[OnnxSegmentationService] Load failed: $e');
        logger.e(st.toString());
      }
      rethrow;
    } finally {
      _isLoadingModel = false;
    }
  }

  Future<File> segment(File inputFile, {bool useUnionMask = true}) async {
    if (!_modelLoaded) {
      await loadModel();
      if (!_modelLoaded || _session == null) {
        throw Exception('ONNX segmentation model failed to load.');
      }
    }

    try {
      final Uint8List imgBytes = await inputFile.readAsBytes();
      final img.Image? decoded = img.decodeImage(imgBytes);
      if (decoded == null) throw Exception('Failed to decode image.');

      // 简化：使用原始尺寸按通道打平成 Float32（RGB，0..1）
      final int imageHeight = decoded.height;
      final int imageWidth = decoded.width;
      final r = <double>[];
      final g = <double>[];
      final b = <double>[];
      for (int y = 0; y < imageHeight; y++) {
        for (int x = 0; x < imageWidth; x++) {
          final p = decoded.getPixel(x, y);
          r.add(p.r / 255.0);
          g.add(p.g / 255.0);
          b.add(p.b / 255.0);
        }
      }
      final floatData = <double>[...r, ...g, ...b];
      final inputOrt = OrtValueTensor.createTensorWithDataList(
        Float32List.fromList(floatData),
        [1, 3, imageHeight, imageWidth],
      );

      final runOptions = OrtRunOptions();
      final outputs = _session!.run(runOptions, {'input': inputOrt});

      // 假设 masks 输出位于 outputs[3]
      final masks4D = outputs[3]!.value as List; // [N,1,H,W]
      final List<List<List<double>>> rawMasks =
          masks4D.map((detection) {
            final mask2dDynamic = (detection as List)[0];
            return (mask2dDynamic as List)
                .map<List<double>>((row) => (row as List).cast<double>())
                .toList();
          }).toList();

      // 合并掩码
      final int h = rawMasks.first.length;
      final int w = rawMasks.first[0].length;
      final unionMask = List.generate(h, (_) => List<bool>.filled(w, false));
      for (final mask2d in rawMasks) {
        for (int y = 0; y < h; y++) {
          for (int x = 0; x < w; x++) {
            if (mask2d[y][x] > 0.5) unionMask[y][x] = true;
          }
        }
      }
      final maskImage = img.Image(width: w, height: h);
      for (int y = 0; y < h; y++) {
        for (int x = 0; x < w; x++) {
          if (unionMask[y][x]) {
            maskImage.setPixel(x, y, decoded.getPixel(x, y));
          } else {
            maskImage.setPixelRgba(x, y, 0, 0, 0, 255);
          }
        }
      }
      final out = File('${Directory.systemTemp.path}/mask_union_onnx.png');
      await out.writeAsBytes(img.encodePng(maskImage));

      inputOrt.release();
      runOptions.release();
      return out;
    } catch (e, st) {
      if (kDebugMode) {
        logger.e('[OnnxSegmentationService] Segmentation failed: $e');
        logger.e(st.toString());
      }
      rethrow;
    }
  }

  void dispose() {
    _session?.release();
    OrtEnv.instance.release();
    _modelLoaded = false;
  }
}
