
// Conditionally import the platform-specific implementations

// Define function signatures for the factory constructors
typedef TfliteInterpreterFactory = TfliteInterpreterWrapper Function();
typedef TfliteOptionsFactory = TfliteInterpreterOptions Function();

// Abstract class defining the TFLite operations needed by DetectionService
abstract class TfliteInterpreterWrapper {
  // Static function pointer to be set by the wrapper
  static TfliteInterpreterFactory? _factory;
  static void setFactory(TfliteInterpreterFactory factory) {
    _factory = factory;
  }

  // Factory constructor
  factory TfliteInterpreterWrapper() {
    if (_factory == null) {
      throw StateError(
        'TfliteInterpreterWrapper factory not set. Call TfliteInterpreterWrapper.setFactory from tflite_wrapper.dart',
      );
    }
    return _factory!();
  }

  Future<void> loadModel(String modelPath, {TfliteInterpreterOptions? options});
  void run(
    Object input,
    Object output,
  ); // Changed to synchronous if tflite_flutter's run is sync
  void close();
  bool get isModelLoaded;

  TensorWrapper getInputTensor(int index);
  TensorWrapper getOutputTensor(int index);
}

// Abstract or placeholder for TfliteInterpreterOptions
abstract class TfliteInterpreterOptions {
  // Static function pointer to be set by the wrapper
  static TfliteOptionsFactory? _factory;
  static void setFactory(TfliteOptionsFactory factory) {
    _factory = factory;
  }

  // Factory constructor
  factory TfliteInterpreterOptions() {
    if (_factory == null) {
      throw StateError(
        'TfliteInterpreterOptions factory not set. Call TfliteInterpreterOptions.setFactory from tflite_wrapper.dart',
      );
    }
    return _factory!();
  }

  int? threads;
}

// Abstract wrapper for Tensor details
abstract class TensorWrapper {
  List<int> get shape;
  TfliteDataTypeWrapper get type;
  // Add other tensor properties if needed, e.g., name
}

// Enum to represent TFLite data types in an abstract way
// Mirroring tflite_flutter's TensorType for mapping
enum TfliteDataTypeWrapper {
  float32,
  int32,
  uint8,
  int64,
  boolean,
  int16,
  string, // Added from common types, check if tflite_flutter actually supports it directly for tensors
  int8, // Added for completeness
  // Add others from tfl.TensorType if needed, ensure mapping is correct
  unsupported, // Fallback for unmapped types
}
