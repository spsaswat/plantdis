import 'dart:convert';

import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;
import 'package:flutter/services.dart' show rootBundle;

import 'api_runtime_secrets_load_io.dart'
    if (dart.library.html) 'api_runtime_secrets_load_stub.dart' as config_file;
import 'package:flutter_test_application_1/utils/logger.dart';

/// Loads API keys from (in order of merge per field):
/// 1. **Flutter asset** [bundledConfigAssetPath] (committed placeholder; listed in pubspec).
/// 2. **Filesystem** [apiFileName] (see [config_file.readConfigJsonFile]): env / bundle Resources / etc.
/// 3. **`--dart-define=GEMINI_API_KEY` / `OPENROUTER_API_KEY`** for any slot still empty.
///
/// For each key, a non-empty filesystem value overrides the bundled asset (handy for local dev).
class ApiRuntimeSecrets {
  ApiRuntimeSecrets._();

  static const String defaultConfigFileName = 'api_config.json';
  static const String bundledConfigAssetPath = 'assets/secrets/api_config.json';

  static String _gemini = '';
  static String _openrouter = '';
  static String? _configFilePathHint;

  static String get geminiApiKey => _gemini;
  static String get openrouterApiKey => _openrouter;

  /// Source hint: filesystem path, or `asset:assets/secrets/api_config.json` when keys came only from the bundle.
  static String? get configFilePathHint => _configFilePathHint;

  static (String, String) _parseApiKeysFromJsonText(String raw) {
    try {
      var text = raw.trim();
      if (text.isNotEmpty && text.codeUnitAt(0) == 0xFEFF) {
        text = text.substring(1);
      }
      final m = jsonDecode(text) as Map<String, dynamic>;
      final g = (m['geminiApiKey'] as String? ?? '').trim();
      final o = (m['openrouterApiKey'] as String? ?? '').trim();
      return (g, o);
    } catch (e, st) {
      if (kDebugMode) {
        logger.e('[ApiConfig] JSON parse error: $e\n$st');
      }
      return ('', '');
    }
  }

  static Future<void> init({String apiFileName = defaultConfigFileName}) async {
    _gemini = '';
    _openrouter = '';
    _configFilePathHint = null;

    if (kDebugMode) {
      if (kIsWeb) {
        logger.d(
          '[ApiConfig] init() $apiFileName (embedded asset + dart-define; no local file on web)',
        );
      } else {
        logger.d(
          '[ApiConfig] init() $apiFileName (embedded asset + filesystem + dart-define)',
        );
      }
    }

    var geminiAsset = '';
    var openAsset = '';
    try {
      final rawAsset = await rootBundle.loadString(bundledConfigAssetPath);
      final p = _parseApiKeysFromJsonText(rawAsset);
      geminiAsset = p.$1;
      openAsset = p.$2;
      if (kDebugMode) {
        logger.d(
          '[ApiConfig] embedded asset lengths: gemini=${geminiAsset.length} openrouter=${openAsset.length}',
        );
      }
    } catch (e) {
      if (kDebugMode) {
        logger.d(
          '[ApiConfig] embedded asset not available ($bundledConfigAssetPath): $e',
        );
      }
    }

    final rawFile = await config_file.readConfigJsonFile(apiFileName);
    _configFilePathHint = config_file.lastReadableApiConfigPath;

    var geminiFile = '';
    var openFile = '';
    if (rawFile != null && rawFile.trim().isNotEmpty) {
      final p = _parseApiKeysFromJsonText(rawFile);
      geminiFile = p.$1;
      openFile = p.$2;
      if (kDebugMode) {
        logger.d(
          '[ApiConfig] filesystem lengths: gemini=${geminiFile.length} openrouter=${openFile.length}',
        );
      }
    } else if (kDebugMode && !kIsWeb) {
      logger.w(
        '[ApiConfig] no filesystem config text (null or empty). Check logs above for paths tried.',
      );
    }

    _gemini = geminiFile.isNotEmpty ? geminiFile : geminiAsset;
    _openrouter = openFile.isNotEmpty ? openFile : openAsset;

    if (geminiFile.isNotEmpty || openFile.isNotEmpty) {
      _configFilePathHint = config_file.lastReadableApiConfigPath;
    } else if (geminiAsset.isNotEmpty || openAsset.isNotEmpty) {
      _configFilePathHint = 'asset:$bundledConfigAssetPath';
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
    if (_gemini.isEmpty && _openrouter.isEmpty) {
      logger.w(
        '[ApiConfig] Config JSON loaded but both keys are empty. '
        'Use string keys exactly "geminiApiKey" and "openrouterApiKey" (see api_config.json.example), '
        'ensure assets/secrets/api_config.json is bundled, save filesystem overrides, '
        'or use --dart-define=GEMINI_API_KEY / OPENROUTER_API_KEY.',
      );
    }
  }
}
