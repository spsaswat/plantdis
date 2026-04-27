/// Non-`dart:io` platforms (e.g. web): no local file; use `--dart-define` only.
String? lastReadableApiConfigPath;

Future<String?> readConfigJsonFile(String fileName) async {
  lastReadableApiConfigPath = null;
  return null;
}
