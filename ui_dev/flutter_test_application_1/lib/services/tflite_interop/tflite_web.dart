import 'dart:typed_data';
import './tflite_interface.dart';
import 'package:flutter_test_application_1/utils/logger.dart';

// This function will be called by tflite_wrapper.dart on web platforms.
void initializePlatformSpecificFactories() {
  TfliteInterpreterWrapper.setFactory(() => TfliteInterpreterWeb());
  TfliteInterpreterOptions.setFactory(() => WebInterpreterOptions());
}

// Web stub implementation
class TfliteInterpreterWeb implements TfliteInterpreterWrapper {
  bool _loaded =
      true; // Assume TF.js handles its own loading state; this stub is always "ready"

  @override
  bool get isModelLoaded => _loaded;

  @override
  Future<void> loadModel(
    String modelPath, {
    TfliteInterpreterOptions? options,
  }) async {
    logger.i(
      '[TfliteInterpreterWeb] loadModel called (stub). TF.js part handled elsewhere.',
    );
    // No actual tflite_flutter loading on web
    await Future.value();
  }

  @override
  void run(Object input, Object output) {
    logger.w(
      '[TfliteInterpreterWeb] run called (stub). Should not be reached.',
    );
    throw UnimplementedError('TFLite run() stub called on web. Use TF.js.');
  }

  @override
  void close() {
    logger.i('[TfliteInterpreterWeb] close called (stub).');
    // No tflite_flutter resources to dispose on web
  }

  @override
  TensorWrapper getInputTensor(int index) {
    logger.w(
      '[TfliteInterpreterWeb] getInputTensor called (stub). Should not be reached.',
    );
    // Return a dummy tensor wrapper instead of throwing
    return WebTensorWrapper([1, 224, 224, 3], TfliteDataTypeWrapper.float32);
  }

  @override
  TensorWrapper getOutputTensor(int index) {
    logger.w(
      '[TfliteInterpreterWeb] getOutputTensor called (stub). Should not be reached.',
    );
    // Return a dummy tensor wrapper instead of throwing
    return WebTensorWrapper([1, 1000], TfliteDataTypeWrapper.float32);
  }
}

class WebInterpreterOptions implements TfliteInterpreterOptions {
  @override
  int? threads;
}

// Dummy TensorWrapper implementation for web
class WebTensorWrapper implements TensorWrapper {
  @override
  final List<int> shape;
  @override
  final TfliteDataTypeWrapper type;

  WebTensorWrapper(this.shape, this.type);
}
