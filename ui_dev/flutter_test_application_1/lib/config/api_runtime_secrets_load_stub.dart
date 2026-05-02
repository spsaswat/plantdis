/// Non-`dart:io` platforms (e.g. web): no filesystem config.
/// [ApiRuntimeSecrets.init] still loads the embedded asset + `--dart-define`.
String? lastReadableApiConfigPath;

Future<String?> readConfigJsonFile(String fileName) async {
  lastReadableApiConfigPath = null;
  return null;
}
