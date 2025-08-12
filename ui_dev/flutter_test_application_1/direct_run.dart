// A direct Dart script to build and run Flutter apps
import 'dart:io';
import 'dart:async';
import 'lib/utils/logger.dart';

void main(List<String> args) async {
  logger.i('===== Flutter Direct Runner =====');

  // Configuration
  const flutterRoot = 'C:\\flutter';
  const dartSdkPath = '$flutterRoot\\bin\\cache\\dart-sdk';
  const dartExe = '$dartSdkPath\\bin\\dart.exe';
  const flutterToolsSnapshot =
      '$flutterRoot\\bin\\cache\\flutter_tools.snapshot';
  const packageConfig =
      '$flutterRoot\\packages\\flutter_tools\\.dart_tool\\package_config.json';
  final workingDirectory = Directory.current.path;
  final androidSdkPath =
      Platform.environment['ANDROID_SDK_ROOT'] ??
      'C:\\Users\\polis\\AppData\\Local\\Android\\Sdk';
  final adbPath = '$androidSdkPath\\platform-tools\\adb.exe';

  logger.i('Checking emulator status...');

  // First check available devices
  final devicesResult = await Process.run(adbPath, ['devices']);
  logger.i('ADB Devices:');
  logger.i(devicesResult.stdout);

  if (!devicesResult.stdout.toString().contains('emulator-5554')) {
    logger.i('Emulator not found. Starting emulator...');
    // List available emulators
    final emulatorsResult = await runFlutterCommand(
      dartExe,
      packageConfig,
      flutterToolsSnapshot,
      ['emulators'],
      workingDirectory,
    );
    logger.i(emulatorsResult.stdout);

    // Start the Pixel 6 Pro emulator
    logger.i('Launching Pixel 6 Pro emulator...');
    await Process.run('$androidSdkPath\\emulator\\emulator.exe', [
      '-avd',
      'Pixel_6_Pro_API_35',
      '-no-snapshot-load',
      '-no-boot-anim',
    ]);

    logger.i(
      'Waiting for emulator to start and be ready (this may take a few minutes)...',
    );
    bool emulatorReady = false;
    for (var i = 0; i < 120; i++) {
      // Try for 2 minutes
      await Future.delayed(const Duration(seconds: 2));
      final checkResult = await Process.run(adbPath, ['devices']);
      final output = checkResult.stdout.toString();

      if (output.contains('emulator-5554')) {
        // Check if boot is complete
        final bootCheck = await Process.run(adbPath, [
          'shell',
          'getprop',
          'sys.boot_completed',
        ]);

        if (bootCheck.stdout.toString().trim() == '1') {
          emulatorReady = true;
          logger.i('Emulator is ready!');
          // Give it a few more seconds to fully initialize
          await Future.delayed(const Duration(seconds: 10));
          break;
        }
      }

      if (i % 15 == 0) {
        // Show progress every 30 seconds
        logger.i('Still waiting for emulator to start... (${i * 2} seconds)');
        logger.i('Current status: ${output.trim()}');
      }
    }

    if (!emulatorReady) {
      logger.e('Error: Emulator failed to start in time');
      logger.w(
        'Please try starting the emulator manually using Android Studio',
      );
      exit(1);
    }
  }

  logger.i('Running pub get...');
  final pubGetResult = await runFlutterCommand(
    dartExe,
    packageConfig,
    flutterToolsSnapshot,
    ['pub', 'get'],
    workingDirectory,
  );

  if (pubGetResult.exitCode != 0) {
    logger.e('Error running pub get');
    exit(1);
  }

  logger.i('Building and running on emulator...');
  final runResult = await runFlutterCommand(
    dartExe,
    packageConfig,
    flutterToolsSnapshot,
    ['run', '--no-pub', '-d', 'emulator-5554'],
    workingDirectory,
  );

  logger.i(runResult.stdout);
  if (runResult.exitCode != 0) {
    logger.e('Error running app:');
    logger.e(runResult.stderr);
    exit(1);
  }
}

Future<ProcessResult> runFlutterCommand(
  String dartExe,
  String packageConfig,
  String flutterToolsSnapshot,
  List<String> args,
  String workingDirectory,
) async {
  final List<String> command = [
    '--packages=$packageConfig',
    flutterToolsSnapshot,
    ...args,
  ];

  logger.i('Running: ${args.join(' ')}');

  final result = await Process.run(
    dartExe,
    command,
    workingDirectory: workingDirectory,
  );

  if (result.stdout.toString().isNotEmpty) {
    logger.i(result.stdout);
  }
  return result;
}
