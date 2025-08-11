import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_test_application_1/utils/web_utils.dart';

import '../../data/constants.dart';
import '../../data/notifiers.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  // This function now contains the logic to toggle the theme.
  // It's called by the Switch widget.
  Future<void> _toggleTheme(bool isDark) async {
    isDarkModeNotifier.value = isDark;
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool(KKeys.themeModeKey, isDark);
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
          )
        ],
      ),
    );
  }
}