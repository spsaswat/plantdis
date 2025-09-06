import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/constants.dart';
import '../../data/notifiers.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key, required this.title});

  final String title;
  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  Future<void> _toggleTheme(bool isDark) async {
    isDarkModeNotifier.value = isDark;
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool(KKeys.themeModeKey, isDark);
  }

  Future<void> _setConfidenceThreshold(int value) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setInt('seg_conf_threshold', value); // 0-100
  }

  Future<void> _setDefaultSegModel(String model) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('seg_default_model', model); // 'tflite' | 'onnx'
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Settings"), // The title is now more generic
        centerTitle: true,
        backgroundColor: Colors.green,
      ),
      // Using a ListView is perfect for settings pages.
      body: ListView(
        children: [
          // We use a ValueListenableBuilder to rebuild only the Switch
          // when the theme changes, which is very efficient.
          ValueListenableBuilder<bool>(
            valueListenable: isDarkModeNotifier,
            builder: (context, isDarkMode, child) {
              return ListTile(
                leading: Icon(isDarkMode ? Icons.dark_mode : Icons.light_mode),
                title: const Text('Dark Mode'),
                subtitle: const Text('Enable or disable the dark theme'),
                // A Switch is the best widget for a true/false setting.
                trailing: Switch(
                  value: isDarkMode,
                  onChanged: (value) {
                    _toggleTheme(value);
                  },
                ),
              );
            },
          ),
          FutureBuilder<SharedPreferences>(
            future: SharedPreferences.getInstance(),
            builder: (context, snap) {
              final prefs = snap.data;
              final current = prefs?.getInt('seg_conf_threshold') ?? 80;
              return ListTile(
                leading: const Icon(Icons.tune),
                title: const Text('SegmentationConfidence Threshold'),
                subtitle: Text('Current: $current%'),
                trailing: DropdownButton<int>(
                  value: current,
                  items:
                      const [60, 70, 80, 85, 90, 95]
                          .map(
                            (e) =>
                                DropdownMenuItem(value: e, child: Text('$e%')),
                          )
                          .toList(),
                  onChanged: (v) {
                    if (v == null) return;
                    _setConfidenceThreshold(v);
                    setState(() {});
                  },
                ),
              );
            },
          ),
          FutureBuilder<SharedPreferences>(
            future: SharedPreferences.getInstance(),
            builder: (context, snap) {
              final prefs = snap.data;
              final model = prefs?.getString('seg_default_model') ?? 'tflite';
              return ListTile(
                leading: const Icon(Icons.memory),
                title: const Text('Default Segmentation Model'),
                subtitle: Text(model.toUpperCase()),
                trailing: DropdownButton<String>(
                  value: model,
                  items: const [
                    DropdownMenuItem(value: 'tflite', child: Text('TFLite')),
                    DropdownMenuItem(value: 'onnx', child: Text('ONNX')),
                  ],
                  onChanged: (v) {
                    if (v == null) return;
                    _setDefaultSegModel(v);
                    setState(() {});
                  },
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
