// Compile-time fallback when `dart:io` is unavailable (e.g. web). Not used at runtime on web.
Future<bool> isDroneImageForPath(String path) async => false;
