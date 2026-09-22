import 'dart:async';
import 'dart:io';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});
  // Use the SDK's Roboto font rather than Ahem's square glyphs for layout tests.
  // Resolve via the installed Flutter package, without a machine-specific path.
  final configFile = File('.dart_tool/package_config.json').absolute;
  final config =
      jsonDecode(await configFile.readAsString()) as Map<String, dynamic>;
  final flutter = (config['packages'] as List)
      .cast<Map<String, dynamic>>()
      .singleWhere((package) => package['name'] == 'flutter');
  final flutterRoot = configFile.uri.resolve('${flutter['rootUri']}/');
  final font = File.fromUri(
    flutterRoot.resolve(
      '../../bin/cache/artifacts/material_fonts/Roboto-Regular.ttf',
    ),
  );
  final loader = FontLoader('Roboto')
    ..addFont(Future.value(ByteData.sublistView(await font.readAsBytes())));
  await loader.load();
  await testMain();
}
