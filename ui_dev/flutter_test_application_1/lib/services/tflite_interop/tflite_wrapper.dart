// We don't need kIsWeb here anymore as the conditional import handles the branching.
// import 'package:flutter/foundation.dart' show kIsWeb;

// Import the interface to access setFactory and for re-exporting

// Conditionally import the platform-specific file and give it an alias.
// This will import tflite_mobile.dart (and its initializePlatformSpecificFactories)
// or tflite_web.dart (and its initializePlatformSpecificFactories).
import 'tflite_mobile.dart'
    if (dart.library.html) 'tflite_web.dart'
    as platform_specific_impl;

// Export the interface so other parts of the app can use it.
export 'tflite_interface.dart';

/// Initializes the factories for TfliteInterpreterWrapper and TfliteInterpreterOptions.
/// This should be called once at app startup, e.g., in main().
void initializeTfliteFactories() {
  // Call the specific initialization function from the imported file.
  platform_specific_impl.initializePlatformSpecificFactories();
}
