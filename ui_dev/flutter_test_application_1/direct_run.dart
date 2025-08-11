// A direct Dart script to build and run Flutter apps
import 'dart:io';
import 'dart:async';

void main(List<String> args) async {
  print('===== Flutter Direct Runner =====');
  
  // Configuration
  const flutterRoot = 'C:\\flutter';
  const dartSdkPath = '$flutterRoot\\bin\\cache\\dart-sdk';
  const dartExe = '$dartSdkPath\\bin\\dart.exe';
  const flutterToolsSnapshot = '$flutterRoot\\bin\\cache\\flutter_tools.snapshot';
  const packageConfig = '$flutterRoot\\packages\\flutter_tools\\.dart_tool\\package_config.json';
  final workingDirectory = Directory.current.path;
  final androidSdkPath = Platform.environment['ANDROID_SDK_ROOT'] ?? 'C:\\Users\\polis\\AppData\\Local\\Android\\Sdk';
  final adbPath = '$androidSdkPath\\platform-tools\\adb.exe';
  
  print('Checking emulator status...');
  
  // First check available devices
  final devicesResult = await Process.run(adbPath, ['devices']);
  print('ADB Devices:');
  print(devicesResult.stdout);
  
  if (!devicesResult.stdout.toString().contains('emulator-5554')) {
    print('Emulator not found. Starting emulator...');
    // List available emulators
    final emulatorsResult = await runFlutterCommand(
      dartExe,
      packageConfig,
      flutterToolsSnapshot,
      ['emulators'],
      workingDirectory,
    );
    print(emulatorsResult.stdout);
    
    // Start the Pixel 6 Pro emulator
    print('Launching Pixel 6 Pro emulator...');
    await Process.run('$androidSdkPath\\emulator\\emulator.exe', [
      '-avd', 
      'Pixel_6_Pro_API_35',
      '-no-snapshot-load',
      '-no-boot-anim',
    ]);
    
    print('Waiting for emulator to start and be ready (this may take a few minutes)...');
    bool emulatorReady = false;
    for (var i = 0; i < 120; i++) {  // Try for 2 minutes
      await Future.delayed(const Duration(seconds: 2));
      final checkResult = await Process.run(adbPath, ['devices']);
      final output = checkResult.stdout.toString();
      
      if (output.contains('emulator-5554')) {
        // Check if boot is complete
        final bootCheck = await Process.run(
          adbPath, 
          ['shell', 'getprop', 'sys.boot_completed']
        );
        
        if (bootCheck.stdout.toString().trim() == '1') {
          emulatorReady = true;
          print('Emulator is ready!');
          // Give it a few more seconds to fully initialize
          await Future.delayed(const Duration(seconds: 10));
          break;
        }
      }
      
      if (i % 15 == 0) {  // Show progress every 30 seconds
        print('Still waiting for emulator to start... (${i*2} seconds)');
        print('Current status: ${output.trim()}');
      }
    }
    
    if (!emulatorReady) {
      print('Error: Emulator failed to start in time');
      print('Please try starting the emulator manually using Android Studio');
      exit(1);
    }
  }
  
  print('Running pub get...');
  final pubGetResult = await runFlutterCommand(
    dartExe,
    packageConfig,
    flutterToolsSnapshot,
    ['pub', 'get'],
    workingDirectory,
  );
  
  if (pubGetResult.exitCode != 0) {
    print('Error running pub get');
    exit(1);
  }
  
  print('Building and running on emulator...');
  final runResult = await runFlutterCommand(
    dartExe,
    packageConfig,
    flutterToolsSnapshot,
    ['run', '--no-pub', '-d', 'emulator-5554'],
    workingDirectory,
  );
  
  print(runResult.stdout);
  if (runResult.exitCode != 0) {
    print('Error running app:');
    print(runResult.stderr);
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
  
  print('Running: ${args.join(' ')}');
  
  final result = await Process.run(
    dartExe,
    command,
    workingDirectory: workingDirectory,
  );
  
  if (result.stdout.toString().isNotEmpty) {
    print(result.stdout);
  }
  return result;
}
