import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;

/// Whether [path] should be opened with [File] instead of HTTP.
///
/// Covers Unix absolute paths, `file://`, and Windows `C:\` / `C:/` (Guest local temp).
bool isLocalFilesystemPath(String path) {
  if (path.isEmpty) return false;
  final p = path.trim();
  if (p.startsWith('file://')) return true;
  if (p.startsWith('/')) return true;
  if (!kIsWeb && Platform.isWindows) {
    return RegExp(r'^[A-Za-z]:[/\\]').hasMatch(p);
  }
  return false;
}

/// Normalizes `file://` to a native path; otherwise returns [path] unchanged.
String toLocalFilePath(String path) {
  final p = path.trim();
  if (p.startsWith('file://')) {
    return Uri.parse(p).toFilePath();
  }
  return p;
}
