import 'package:tflite_flutter/tflite_flutter.dart' as tfl;
import 'tflite_interface.dart' as iface;

/// Initialize TFLite factories to unified mobile/web implementation
void initializeTfliteFactories() {
  iface.TfliteInterpreterWrapper.setFactory(() => _AdapterInterpreter());
  iface.TfliteInterpreterOptions.setFactory(() => _AdapterOptions());
}

/// Adapter: iface -> tflite_flutter
class _AdapterInterpreter implements iface.TfliteInterpreterWrapper {
  tfl.Interpreter? _interpreter;
  bool _loaded = false;

  @override
  bool get isModelLoaded => _loaded;

  @override
  Future<void> loadModel(
    String modelPath, {
    iface.TfliteInterpreterOptions? options,
  }) async {
    final opts = tfl.InterpreterOptions();
    if (options != null && options.threads != null) {
      opts.threads = options.threads!;
    }
    _interpreter = await tfl.Interpreter.fromAsset(modelPath, options: opts);
    _interpreter!.allocateTensors();
    _loaded = true;
  }

  @override
  void run(Object input, Object output) {
    if (_interpreter == null || !_loaded) {
      throw StateError('TFLite interpreter not loaded');
    }
    // Support both single and multi-IO via the same entrypoint
    if (input is List<Object> && output is Map<int, Object>) {
      _interpreter!.runForMultipleInputs(input, output);
      return;
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
  iface.TensorWrapper getInputTensor(int index) {
    if (_interpreter == null || !_loaded) {
      throw StateError('TFLite interpreter not loaded');
    }
    return _AdapterTensor(_interpreter!.getInputTensor(index));
  }

  @override
  iface.TensorWrapper getOutputTensor(int index) {
    if (_interpreter == null || !_loaded) {
      throw StateError('TFLite interpreter not loaded');
    }
    return _AdapterTensor(_interpreter!.getOutputTensor(index));
  }
}

class _AdapterOptions implements iface.TfliteInterpreterOptions {
  @override
  int? threads;
}

class _AdapterTensor implements iface.TensorWrapper {
  final tfl.Tensor _tensor;
  _AdapterTensor(this._tensor);

  @override
  List<int> get shape => _tensor.shape;

  @override
  iface.TfliteDataTypeWrapper get type {
    switch (_tensor.type) {
      case tfl.TensorType.float32:
        return iface.TfliteDataTypeWrapper.float32;
      case tfl.TensorType.int32:
        return iface.TfliteDataTypeWrapper.int32;
      case tfl.TensorType.uint8:
        return iface.TfliteDataTypeWrapper.uint8;
      case tfl.TensorType.int64:
        return iface.TfliteDataTypeWrapper.int64;
      case tfl.TensorType.boolean:
        return iface.TfliteDataTypeWrapper.boolean;
      case tfl.TensorType.int16:
        return iface.TfliteDataTypeWrapper.int16;
      case tfl.TensorType.string:
        return iface.TfliteDataTypeWrapper.string;
      case tfl.TensorType.int8:
        return iface.TfliteDataTypeWrapper.int8;
      default:
        return iface.TfliteDataTypeWrapper.unsupported;
    }
  }
}

/// Simple direct wrapper (per-instance, no singleton)
class TfliteOptions {
  int? threads;
}

class TfliteTensor {
  final tfl.Tensor _tensor;
  TfliteTensor(this._tensor);
  List<int> get shape => _tensor.shape;
}

class TfliteInterpreter {
  tfl.Interpreter? _interpreter;
  bool _isLoaded = false;

  bool get isModelLoaded => _isLoaded;

  Future<void> loadModel(String modelPath, {TfliteOptions? options}) async {
    final interpreterOptions = tfl.InterpreterOptions();
    if (options?.threads != null) {
      interpreterOptions.threads = options!.threads!;
    }
    _interpreter = await tfl.Interpreter.fromAsset(
      modelPath,
      options: interpreterOptions,
    );
    _interpreter!.allocateTensors();
    _isLoaded = true;
  }

  void run(Object input, Object output) {
    _ensure();
    _interpreter!.run(input, output);
  }

  void runForMultipleInputs(List<Object> inputs, Map<int, Object> outputs) {
    _ensure();
    _interpreter!.runForMultipleInputs(inputs, outputs);
  }

  TfliteTensor getInputTensor(int index) {
    _ensure();
    return TfliteTensor(_interpreter!.getInputTensor(index));
  }

  TfliteTensor getOutputTensor(int index) {
    _ensure();
    return TfliteTensor(_interpreter!.getOutputTensor(index));
  }

  void close() => dispose();

  void dispose() {
    _interpreter?.close();
    _interpreter = null;
    _isLoaded = false;
  }

  void _ensure() {
    if (_interpreter == null || !_isLoaded) {
      throw StateError('TFLite interpreter not loaded');
    }
  }
}
