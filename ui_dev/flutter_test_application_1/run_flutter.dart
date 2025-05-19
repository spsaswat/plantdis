// Direct Flutter runner script
// This script allows you to run Flutter commands without using the corrupted batch files
// Usage: dart run_flutter.dart [args]
// Example: dart run_flutter.dart run -d chrome

import 'dart:io';

void main(List<String> args) async {
  // Configuration
  final flutterRoot = 'C:\\flutter';
  final dartSdkPath = '$flutterRoot\\bin\\cache\\dart-sdk';
  final dartExe = '$dartSdkPath\\bin\\dart.exe';
  final flutterToolsSnapshot = '$flutterRoot\\bin\\cache\\flutter_tools.snapshot';
  final packageConfig = '$flutterRoot\\packages\\flutter_tools\\.dart_tool\\package_config.json';
  
  // Current directory is the Flutter project
  final workingDirectory = Directory.current.path;
  
  print('===== Flutter Direct Runner =====');
  print('Flutter root: $flutterRoot');
  print('Working directory: $workingDirectory');
  print('Command: ${args.join(' ')}');
  print('');
  
  // Check if Dart SDK exists
  if (!File(dartExe).existsSync()) {
    print('ERROR: Dart executable not found at $dartExe');
    print('Please check your Flutter installation');
    exit(1);
  }
  
  // If no args provided, show help
  if (args.isEmpty) {
    print('Usage: dart run_flutter.dart [flutter_command]');
    print('Examples:');
    print('  dart run_flutter.dart pub get');
    print('  dart run_flutter.dart run -d chrome');
    print('  dart run_flutter.dart build apk');
    exit(0);
  }
  
  try {
    // Execute the Flutter command through dart
    final process = await Process.start(
      dartExe,
      [
        '--packages=$packageConfig',
        flutterToolsSnapshot,
        ...args,
      ],
      workingDirectory: workingDirectory,
    );
    
    // Connect standard IO
    stdin.pipe(process.stdin);
    process.stdout.pipe(stdout);
    process.stderr.pipe(stderr);
    
    // Wait for process to complete
    final exitCode = await process.exitCode;
    print('\nProcess exited with code $exitCode');
    exit(exitCode);
  } catch (e) {
    print('ERROR: Failed to execute command: $e');
    exit(1);
  }
}
