import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test_application_1/config/api_runtime_secrets.dart';

/// The application sees only synthetic credentials, even if the developer has
/// PLANTDIS_API_CONFIG or a real api_config.json on this machine.
Future<void> setupApiTestKeys() => IOOverrides.runZoned(
  () => ApiRuntimeSecrets.init(),
  createFile: (path) => _TestConfigFile(path),
);

class _TestConfigFile extends Fake implements File {
  _TestConfigFile(this.path);
  @override
  final String path;
  @override
  File get absolute => this;
  @override
  Directory get parent => Directory(path).parent;
  @override
  Future<bool> exists() async => true;
  @override
  Future<String> readAsString({Encoding encoding = utf8}) async => jsonEncode({
    'geminiApiKey': 'test-gemini-key',
    'openrouterApiKey': 'test-openrouter-key',
  });
}
