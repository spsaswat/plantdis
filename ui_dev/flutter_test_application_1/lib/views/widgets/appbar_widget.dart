import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/constants.dart';
import '../../data/notifiers.dart';

class AppbarWidget extends StatelessWidget implements PreferredSizeWidget {
  const AppbarWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.green,
      title: Text("Plant Disease Detector"),
      centerTitle: true,
      actions: [
        IconButton(
          padding: EdgeInsets.all(5.0),
          icon: Icon(Icons.energy_savings_leaf_sharp),
          onPressed: () => debugPrint("[Redirect to company page?]"),
        ),
        ValueListenableBuilder(
          valueListenable: isDarkModeNotifier,
          builder: (context, isDarkMode, child) {
            return IconButton(
              padding: EdgeInsets.all(5.0),
              icon: Icon(isDarkMode ? Icons.light_mode : Icons.dark_mode),
              onPressed: () async {
                isDarkModeNotifier.value = !isDarkModeNotifier.value;

                final SharedPreferences prefs =
                    await SharedPreferences.getInstance();
                await prefs.setBool(
                  KKeys.themeModeKey,
                  isDarkModeNotifier.value,
                );
              },
            );
          },
        ),
      ],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
