import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:onnxruntime/onnxruntime.dart';

class SamModel {
  OrtSession? _session;

  Future<void> loadModel() async {
    final sessionOptions = OrtSessionOptions();
    const assetFileName = 'assets/sam_model_v12.onnx';
    final rawAssetFile = await rootBundle.load(assetFileName);
    final bytes = rawAssetFile.buffer.asUint8List();
    _session = OrtSession.fromBuffer(bytes, sessionOptions);
  }

  Future<List<Float32List>> runModel(Uint8List imageEmbedding, Float32List pointCoords, Float32List pointLabels, Float32List maskInput, Float32List hasMaskInput, Float32List origImSize) async {
    if (_session == null) {
      throw Exception('Model is not loaded');
    }

    final inputs = {
      'image_embeddings': OrtValueTensor.createTensorWithDataList(imageEmbedding, [1, 256, 64, 64]),
      'point_coords': OrtValueTensor.createTensorWithDataList(pointCoords, [1, pointCoords.length ~/ 2, 2]),
      'point_labels': OrtValueTensor.createTensorWithDataList(pointLabels, [1, pointLabels.length]),
      'mask_input': OrtValueTensor.createTensorWithDataList(maskInput, [1, 1, 256, 256]),
      'has_mask_input': OrtValueTensor.createTensorWithDataList(hasMaskInput, [1]),
      'orig_im_size': OrtValueTensor.createTensorWithDataList(origImSize, [2]),
    };

    final runOptions = OrtRunOptions();
    final outputs = await _session!.runAsync(runOptions, inputs);

    final masks = outputs?[0] as OrtValueTensor;
    final iouPredictions = outputs?[1] as OrtValueTensor;
    final lowResMasks = outputs?[2] as OrtValueTensor;

    // Assuming we have a method to convert OrtValueTensor to Float32List
    return [
      Float32List.fromList(masks.value),
      Float32List.fromList(iouPredictions.value),
      Float32List.fromList(lowResMasks.value)
    ];
  }
}
