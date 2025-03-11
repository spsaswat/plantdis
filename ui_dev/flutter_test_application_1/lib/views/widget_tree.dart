import 'package:flutter/material.dart';
import 'package:flutter_test_application_1/data/constants.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'widgets/navbar_widget.dart';

import '../data/notifiers.dart';
import 'widgets/drawer_widget.dart';

import 'pages/home_page.dart';
import 'pages/profile_page.dart';

List<Widget> pages = [HomePage(), ProfilePage()];

class WidgetTree extends StatelessWidget {
  const WidgetTree({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        appBar: AppBar(
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
        ),

        drawer: DrawerWidget(),

        body: ValueListenableBuilder(
          valueListenable: selectedPageNotifier,
          builder: (BuildContext context, dynamic selectedPage, Widget? child) {
            return pages.elementAt(selectedPage);
          },
        ),

        floatingActionButton: FloatingActionButton(
          child: Icon(Icons.add_a_photo_rounded),
          onPressed: () => debugPrint("User wants to upload an image."),
        ),

        bottomNavigationBar: NavBarWidget(),
      ),
    );
  }
}
