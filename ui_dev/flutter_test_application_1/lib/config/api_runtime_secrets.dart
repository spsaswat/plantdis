import 'dart:convert';

import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;

import 'api_runtime_secrets_load_io.dart'
    if (dart.library.html) 'api_runtime_secrets_load_stub.dart' as config_file;
import 'package:flutter_test_application_1/utils/logger.dart';

/// Loads API keys at runtime from [apiFileName] (default `api_config.json`).
///
/// Resolution (IO): `PLANTDIS_API_CONFIG` → **macOS:** `Contents/Resources/` inside
/// the `.app` (populated from the project root at **Xcode build** for local dev) →
/// Application Support → walk from binary/cwd. Missing keys use
/// `--dart-define=GEMINI_API_KEY` / `OPENROUTER_API_KEY`.
class ApiRuntimeSecrets {
  ApiRuntimeSecrets._();

  static const String defaultConfigFileName = 'api_config.json';

  static String _gemini = '';
  static String _openrouter = '';
  static String? _configFilePathHint;

  static String get geminiApiKey => _gemini;
  static String get openrouterApiKey => _openrouter;

  /// Path of the `api_config.json` that was actually read, if any (e.g. App Support on macOS).
  static String? get configFilePathHint => _configFilePathHint;

  static Future<void> init({String apiFileName = defaultConfigFileName}) async {
    _gemini = '';
    _openrouter = '';
    if (kDebugMode) {
      if (kIsWeb) {
        logger.d(
          '[ApiConfig] init() on web: no local api_config.json; use --dart-define=GEMINI_API_KEY / OPENROUTER_API_KEY',
        );
      } else {
        logger.d('[ApiConfig] init() loading $apiFileName');
      }
    }
    _configFilePathHint = null;
    final raw = await config_file.readConfigJsonFile(apiFileName);
    _configFilePathHint = config_file.lastReadableApiConfigPath;
    if (raw == null || raw.trim().isEmpty) {
      if (kDebugMode) {
        logger.w(
          '[ApiConfig] no config file text (null or empty). Check logs above for paths tried.',
        );
      }
    } else {
      try {
        // UTF-8 BOM (common for files saved with Windows Notepad) breaks jsonDecode.
        var text = raw.trim();
        if (text.isNotEmpty && text.codeUnitAt(0) == 0xFEFF) {
          text = text.substring(1);
        }
        final m = jsonDecode(text) as Map<String, dynamic>;
        _gemini = (m['geminiApiKey'] as String? ?? '').trim();
        _openrouter = (m['openrouterApiKey'] as String? ?? '').trim();
        if (kDebugMode) {
          logger.d(
            '[ApiConfig] parsed keys: geminiLength=${_gemini.length} openrouterLength=${_openrouter.length} (values not logged)',
          );
        }
        if (_gemini.isEmpty && _openrouter.isEmpty) {
          logger.w(
            '[ApiConfig] Config JSON loaded but both keys are empty. '
            'Use string keys exactly "geminiApiKey" and "openrouterApiKey" (see api_config.json.example), '
            'save the file, then send another message (the app will re-read) or hot-restart (R).',
          );
        }
      } catch (e, st) {
        logger.e(
          '[ApiConfig] JSON parse failed (file may be invalid or wrong format): $e\n$st',
        );
      }
    }
    const dGemini = String.fromEnvironment('GEMINI_API_KEY', defaultValue: '');
    const dOpen = String.fromEnvironment('OPENROUTER_API_KEY', defaultValue: '');
    if (_gemini.isEmpty && dGemini.isNotEmpty) {
      _gemini = dGemini;
      if (kDebugMode) {
        logger.d('[ApiConfig] gemini from --dart-define');
      }
    }
    if (_openrouter.isEmpty && dOpen.isNotEmpty) {
      _openrouter = dOpen;
      if (kDebugMode) {
        logger.d('[ApiConfig] openrouter from --dart-define');
      }
    }
    if (kDebugMode) {
      logger.d(
        '[ApiConfig] after init: gemini=${_gemini.isNotEmpty} openrouter=${_openrouter.isNotEmpty}',
      );
    }
  }
}
