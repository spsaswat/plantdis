// import 'dart:async';
// // ignore: avoid_web_libraries_in_flutter
// import 'package:web/web.dart';
// import 'dart:js' as js;
// import 'package:flutter/foundation.dart' show kIsWeb;

// class WebUtils {
//   static Future<void> requestCameraPermission() async {
//     if (!kIsWeb) return;

//     try {
//       // Call the JS function we defined in index.html
//       await js.context.callMethod('requestCameraPermission');
//     } catch (e) {
//       throw Exception('Camera permission denied: $e');
//     }
//   }

//   static bool get isHttps {
//     if (!kIsWeb) return true; // Non-web platforms are always "secure"

//     // Use the JS variable we set in index.html
//     if (js.context.hasProperty('isOnLocalhost')) {
//       final isLocalhost = js.context['isOnLocalhost'];
//       if (isLocalhost == true) return true;
//     }

//     // Check protocol as fallback
//     return window.location.protocol == 'https:';
//   }

//   // Force allow camera on localhost regardless of protocol
//   static bool get isCameraAllowed {
//     if (!kIsWeb) return true;

//     // Use the JS variable we set in index.html
//     if (js.context.hasProperty('isOnLocalhost')) {
//       final isLocalhost = js.context['isOnLocalhost'];
//       if (isLocalhost == true) return true;
//     }

//     return isHttps;
//   }

//   // Get fallback image as data URL
//   static String? getFallbackImageUrl(String imageName) {
//     if (!kIsWeb) return null;

//     if (js.context.hasProperty('fallbackImages')) {
//       final fallbackImages = js.context['fallbackImages'];
//       if (fallbackImages != null && fallbackImages.hasProperty(imageName)) {
//         return fallbackImages[imageName] as String?;
//       }
//     }

//     return null;
//   }
// }
