import 'dart:io';

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'package:flutter_test_application_1/utils/logger.dart';

/// Set when [readConfigJsonFile] successfully read a file (for user-facing errors).
String? lastReadableApiConfigPath;

/// Reads [fileName] (default `api_config.json`) for API keys.
///
/// **Shared:** [p.join] and [getApplicationSupportDirectory] work the same on every OS
/// (e.g. `%APPDATA%\...` on Windows, `~/Library/.../Application Support/...` on macOS).
///
/// **OS-specific optional steps** (all others are identical):
/// 1. [PLANTDIS_API_CONFIG] if set to a **readable** file.
/// 2. **macOS only:** [fileName] in `.../Contents/Resources/` (Xcode can copy it at
///    build time; required for sandboxed dev to see repo `api_config.json` without
///    manual copy). Do not ship release secrets this way.
/// 3. **Windows / Linux only:** [fileName] in the same directory as the process
///    executable (optional hand-placed or from your own packaging script).
/// 4. [getApplicationSupportDirectory]/[fileName] — per-user override / template.
/// 5. Walk up from the running binary, then from [Directory.current] (dev).
Future<String?> readConfigJsonFile(String fileName) async {
  lastReadableApiConfigPath = null;

  void d(String m) {
    if (kDebugMode) {
      logger.d('[ApiConfig] $m');
    }
  }

  d('resolve fileName=$fileName cwd=${Directory.current.path}');
  d('resolvedExecutable=${Platform.resolvedExecutable}');

  final fromEnv = Platform.environment['PLANTDIS_API_CONFIG']?.trim();
  if (fromEnv != null && fromEnv.isNotEmpty) {
    final f = File(fromEnv);
    d('PLANTDIS_API_CONFIG=$fromEnv');
    final text = await _readFileIfPermitted(f, 'PLANTDIS_API_CONFIG');
    if (text != null) {
      lastReadableApiConfigPath = f.path;
      d('using PLANTDIS_API_CONFIG');
      return text;
    }
  } else {
    d('PLANTDIS_API_CONFIG not set');
  }

  if (Platform.isMacOS) {
    final exe = File(Platform.resolvedExecutable).absolute;
    final inBundle = File(
      p.normalize(p.join(exe.parent.path, '..', 'Resources', fileName)),
    );
    d('bundle Resources candidate: ${inBundle.path} exists=${await inBundle.exists()}');
    final fromBundle = await _readFileIfPermitted(inBundle, 'macOS bundle Resources');
    if (fromBundle != null) {
      lastReadableApiConfigPath = inBundle.path;
      d('using macOS app bundle Resources $fileName');
      return fromBundle;
    }
  } else if (Platform.isWindows || Platform.isLinux) {
    final exeDir = File(Platform.resolvedExecutable).absolute.parent;
    final nextToExe = File(p.join(exeDir.path, fileName));
    d('next-to-exe candidate: ${nextToExe.path} exists=${await nextToExe.exists()}');
    final fromBeside = await _readFileIfPermitted(nextToExe, 'next to executable');
    if (fromBeside != null) {
      lastReadableApiConfigPath = nextToExe.path;
      d('using $fileName next to executable');
      return fromBeside;
    }
  }

  Directory? supportDir;
  try {
    supportDir = await getApplicationSupportDirectory();
    final inSupport = File(p.join(supportDir.path, fileName));
    d('app support: ${inSupport.path} exists=${await inSupport.exists()}');
    var text = await _readFileIfPermitted(inSupport, 'app support');
    if (text == null && !await inSupport.exists()) {
      await _ensureConfigTemplateInAppSupport(inSupport, fileName);
      text = await _readFileIfPermitted(inSupport, 'app support after template');
    }
    if (text != null) {
      lastReadableApiConfigPath = inSupport.path;
      d('using app support file');
      return text;
    }
  } catch (e, st) {
    logger.w('[ApiConfig] getApplicationSupportDirectory failed: $e\n$st');
  }

  final exeParent = File(Platform.resolvedExecutable).absolute.parent;
  d('walk from exe parent: ${exeParent.path}');
  final fromExe = await _readByWalkingUp(
    fileName,
    startDir: exeParent,
    maxHops: 32,
    debugLabel: 'from_exe',
  );
  if (fromExe != null) {
    return fromExe;
  }

  d('walk from cwd: ${Directory.current.path} (maxHops=8)');
  final fromCwd = await _readByWalkingUp(
    fileName,
    startDir: Directory.current,
    maxHops: 8,
    debugLabel: 'from_cwd',
  );
  if (fromCwd != null) {
    return fromCwd;
  }

  if (supportDir != null) {
    final hint = p.join(supportDir.path, fileName);
    logger.w(
      '[ApiConfig] No readable $fileName. For sandboxed macOS, copy the file to:\n  $hint\n'
      '(Or set PLANTDIS_API_CONFIG to a readable path.)',
    );
  }
  return null;
}

Future<String?> _readByWalkingUp(
  String fileName, {
  required Directory startDir,
  required int maxHops,
  String? debugLabel,
}) async {
  final triedAbsolute = <String>{};
  var dir = startDir;
  for (var i = 0; i < maxHops; i++) {
    for (final candidate in _candidatesInDir(dir.path, fileName)) {
      final f = File(candidate);
      final abs = f.absolute.path;
      if (triedAbsolute.contains(abs)) {
        continue;
      }
      triedAbsolute.add(abs);
      if (await f.exists()) {
        if (kDebugMode) {
          logger.d(
            '[ApiConfig] candidate exists (hop=$i${debugLabel != null ? ' $debugLabel' : ''}): $candidate',
          );
        }
        final text = await _readFileIfPermitted(
          f,
          'walk $debugLabel',
        );
        if (text != null) {
          lastReadableApiConfigPath = f.path;
          return text;
        }
      }
    }
    final parent = dir.parent;
    if (parent.path == dir.path) {
      break;
    }
    dir = parent;
  }
  if (kDebugMode) {
    logger.w(
      '[ApiConfig] no file in walk from start=${startDir.path} label=${debugLabel ?? "cwd/exe"} maxHops=$maxHops',
    );
  }
  return null;
}

List<String> _candidatesInDir(String dirPath, String fileName) {
  final a = p.join(dirPath, fileName);
  final b = p.join(dirPath, 'ui_dev', 'flutter_test_application_1', fileName);
  if (p.equals(a, b)) {
    return [a];
  }
  return [a, b];
}

/// Sandboxed macOS can read this path; user fills keys (or paste from project).
Future<void> _ensureConfigTemplateInAppSupport(File target, String fileName) async {
  if (fileName != 'api_config.json') {
    return;
  }
  try {
    await target.parent.create(recursive: true);
    if (await target.exists()) {
      return;
    }
    const content = '{\n'
        '  "geminiApiKey": "",\n'
        '  "openrouterApiKey": ""\n'
        '}\n';
    await target.writeAsString(content);
    logger.i(
      '[ApiConfig] Created $fileName in app support (empty keys). '
      'Edit the file, save, then hot-restart: ${target.path}',
    );
  } catch (e, st) {
    logger.w('[ApiConfig] could not create config template: $e\n$st');
  }
}

/// [File.exists] is not enough on sandboxed macOS: paths outside the container may
/// exist but [readAsString] returns "Operation not permitted" (errno 1).
Future<String?> _readFileIfPermitted(File f, String context) async {
  try {
    if (!await f.exists()) {
      return null;
    }
    return await f.readAsString();
  } on FileSystemException catch (e) {
    if (kDebugMode) {
      logger.w(
        '[ApiConfig] cannot read $context: ${f.path} (${e.message})',
      );
    }
    return null;
  } catch (e) {
    if (kDebugMode) {
      logger.w('[ApiConfig] cannot read $context: ${f.path} — $e');
    }
    return null;
  }
}
