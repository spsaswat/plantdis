// Direct Flutter runner script
// This script allows you to run Flutter commands without using the corrupted batch files
// Usage: dart run_flutter.dart [args]
// Example: dart run_flutter.dart run -d chrome

import 'dart:io';
import 'lib/utils/logger.dart';

void main(List<String> args) async {
  // Configuration
  const flutterRoot = 'C:\\flutter';
  const dartSdkPath = '$flutterRoot\\bin\\cache\\dart-sdk';
  const dartExe = '$dartSdkPath\\bin\\dart.exe';
  const flutterToolsSnapshot =
      '$flutterRoot\\bin\\cache\\flutter_tools.snapshot';
  const packageConfig =
      '$flutterRoot\\packages\\flutter_tools\\.dart_tool\\package_config.json';

  // Current directory is the Flutter project
  final workingDirectory = Directory.current.path;

  logger.i('===== Flutter Direct Runner =====');
  logger.i('Flutter root: $flutterRoot');
  logger.i('Working directory: $workingDirectory');
  logger.i('Command: ${args.join(' ')}');
  logger.i('');

  // Check if Dart SDK exists
  if (!File(dartExe).existsSync()) {
    logger.e('ERROR: Dart executable not found at $dartExe');
    logger.w('Please check your Flutter installation');
    exit(1);
  }

  // If no args provided, show help
  if (args.isEmpty) {
    logger.i('Usage: dart run_flutter.dart [flutter_command]');
    logger.i('Examples:');
    logger.i('  dart run_flutter.dart pub get');
    logger.i('  dart run_flutter.dart run -d chrome');
    logger.i('  dart run_flutter.dart build apk');
    exit(0);
  }

  try {
    // Execute the Flutter command through dart
    final process = await Process.start(dartExe, [
      '--packages=$packageConfig',
      flutterToolsSnapshot,
      ...args,
    ], workingDirectory: workingDirectory);

    // Connect standard IO
    stdin.pipe(process.stdin);
    process.stdout.pipe(stdout);
    process.stderr.pipe(stderr);

    // Wait for process to complete
    final exitCode = await process.exitCode;
    logger.i('\nProcess exited with code $exitCode');
    exit(exitCode);
  } catch (e) {
    logger.e('ERROR: Failed to execute command: $e');
    exit(1);
  }
}
