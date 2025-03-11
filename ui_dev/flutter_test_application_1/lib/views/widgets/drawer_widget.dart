import 'package:flutter/material.dart';
import 'package:flutter_test_application_1/data/notifiers.dart';
import 'package:flutter_test_application_1/views/pages/welcome_page.dart';

import '../pages/settings_page.dart';

class DrawerWidget extends StatelessWidget {
  const DrawerWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: Column(
        children: [
          DrawerHeader(
            child: SizedBox(
              child: Image.asset(
                'assets/images/appn_banner.jpg',
                color: Colors.white,
                colorBlendMode: BlendMode.darken,
              ),
            ),
          ),
          ListTile(
            leading: Icon(Icons.settings),
            title: Text("Settings"),
            onTap:
                () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) {
                      return SettingsPage(title: "Settings");
                    },
                  ),
                ),
          ),

          ListTile(
            leading: Icon(Icons.info_outline_rounded),
            title: Text("About Us"),
            onTap: () => debugPrint("[Display Devs?]"),
          ),

          ListTile(
            leading: Icon(Icons.logout_outlined),
            title: Text("Logout"),
            onTap: () {
              selectedPageNotifier.value = 0;
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) {
                    return WelcomePage();
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
