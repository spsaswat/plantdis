import 'package:tflite_flutter/tflite_flutter.dart' as tfl;
import './tflite_interface.dart';
import 'package:flutter_test_application_1/utils/logger.dart';

// This function will be called by tflite_wrapper.dart on mobile platforms.
void initializePlatformSpecificFactories() {
  TfliteInterpreterWrapper.setFactory(() => TfliteInterpreterMobile());
  TfliteInterpreterOptions.setFactory(() => MobileInterpreterOptions());
}

// Helper to map tfl.TensorType to TfliteDataTypeWrapper
TfliteDataTypeWrapper _mapTensorType(tfl.TensorType type) {
  switch (type) {
    case tfl.TensorType.float32:
      return TfliteDataTypeWrapper.float32;
    case tfl.TensorType.int32:
      return TfliteDataTypeWrapper.int32;
    case tfl.TensorType.uint8:
      return TfliteDataTypeWrapper.uint8;
    case tfl.TensorType.int64:
      return TfliteDataTypeWrapper.int64;
    case tfl.TensorType.boolean:
      return TfliteDataTypeWrapper.boolean;
    case tfl.TensorType.int16:
      return TfliteDataTypeWrapper.int16;
    case tfl.TensorType.string:
      return TfliteDataTypeWrapper.string;
    case tfl.TensorType.int8:
      return TfliteDataTypeWrapper.int8;
    // Add other cases as needed for tfl.TensorType values
    default:
      logger.w('[TfliteInterpreterMobile] Warning: Unmapped TensorType: $type');
      return TfliteDataTypeWrapper.unsupported;
  }
}

class TfliteInterpreterMobile implements TfliteInterpreterWrapper {
  tfl.Interpreter? _interpreter;
  bool _loaded = false;

  @override
  bool get isModelLoaded => _loaded;

  @override
  Future<void> loadModel(
    String modelPath, {
    TfliteInterpreterOptions? options,
  }) async {
    final mobileOptions = tfl.InterpreterOptions();
    if (options?.threads != null) {
      mobileOptions.threads = options!.threads!;
    }
    _interpreter = await tfl.Interpreter.fromAsset(
      modelPath,
      options: mobileOptions,
    );
    _loaded = true;
  }

  @override
  void run(Object input, Object output) {
    if (_interpreter == null || !_loaded) {
      throw Exception('Mobile TFLite model not loaded or uninitialized.');
    }
    _interpreter!.run(input, output);
  }

  @override
  void close() {
    _interpreter?.close();
    _interpreter = null;
    _loaded = false;
  }

  @override
  TensorWrapper getInputTensor(int index) {
    if (_interpreter == null || !_loaded) {
      throw Exception('Mobile TFLite model not loaded or uninitialized.');
    }
    return MobileTensorWrapper(_interpreter!.getInputTensor(index));
  }

  @override
  TensorWrapper getOutputTensor(int index) {
    if (_interpreter == null || !_loaded) {
      throw Exception('Mobile TFLite model not loaded or uninitialized.');
    }
    return MobileTensorWrapper(_interpreter!.getOutputTensor(index));
  }
}

class MobileInterpreterOptions implements TfliteInterpreterOptions {
  @override
  int? threads;
}

class MobileTensorWrapper implements TensorWrapper {
  final tfl.Tensor _tensor;
  MobileTensorWrapper(this._tensor);

  @override
  List<int> get shape => _tensor.shape;

  @override
  TfliteDataTypeWrapper get type => _mapTensorType(_tensor.type);
}
