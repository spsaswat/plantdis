import 'package:flutter/material.dart';
import 'package:flutter_test_application_1/data/notifiers.dart';
import 'package:flutter_test_application_1/views/pages/welcome_page.dart';
import '../../utils/web_utils.dart';
import '../pages/settings_page.dart';

class DrawerWidget extends StatelessWidget {
  const DrawerWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: Column(
        children: [
          DrawerHeader(
            padding: EdgeInsets.zero,
            child: GestureDetector(
              onTap: () => web_utils.launchAPPNWebsite(context),
              child: Padding(
                // EdgeInsets.symmetric is perfect for applying horizontal (left/right)
                // or vertical (top/bottom) padding.
                padding: const EdgeInsets.symmetric(horizontal: 16.0), // Adds 16 pixels of space on both left and right
                child: Image.asset(
                  'assets/images/appn_banner.png',
                  fit: BoxFit.contain, // Keep contain, as it's working well
                ),
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.settings),
            title: const Text("Settings"),
            onTap:
                () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) {
                      return const SettingsPage(title: 'Settings',);
                    },
                  ),
                ),
          ),

          ListTile(
            leading: const Icon(Icons.info_outline_rounded),
            title: const Text("About Us"),
            onTap: () => web_utils.launchPlantDisWebsite(context),
          ),

          const Spacer(),

          ListTile(
            leading: const Icon(Icons.logout_outlined),
            title: const Text("Logout"),
            onTap: () {
              selectedPageNotifier.value = 0;
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) {
                    return const WelcomePage();
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
