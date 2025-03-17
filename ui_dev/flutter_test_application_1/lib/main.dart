import 'package:flutter/material.dart';
import 'package:flutter_test_application_1/data/constants.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'data/notifiers.dart';
import 'views/pages/welcome_page.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    initThemeMode();
  }

  void initThemeMode() async {
    final SharedPreferences pref = await SharedPreferences.getInstance();
    final bool? repeat = pref.getBool(KKeys.themeModeKey);
    isDarkModeNotifier.value = repeat ?? true;
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: isDarkModeNotifier,
      builder: (context, isDarkMode, child) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,

          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.teal,
              brightness: isDarkMode ? Brightness.dark : Brightness.light,
            ),
          ),

          home: WelcomePage(),
        );
      },
    );
  }
}



// ! HTTP (GET/POST)

// ? Workaround: Diable web security at launch.
// ? flutter run -d edge --web-browser-flag "--disable-web-security"

// * The correct solution is from the server side to allow CORS from the requesting 
// * domain and allow the needed methods, and credentials if needed.

// Something along the lines of:
// header('Access-Control-Allow-Origin: *');
// header('Access-Control-Allow-Methods: GET, POST');
// header("Access-Control-Allow-Headers: X-Requested-With");


// ! GENERAL INFO

// * EXPENSIVE
// ? CONTAINER: Versatile, but computationally

// * LESS EXPENSIVE
// ? PADDING:   Use in-place of [container] if only padding is required.
// ? SIZEDBOX:  Use in-place of [container] if only dimensions are required.

// ? WRAP:      Use in-place of [row] if the content exceeds the width

// ? SAFEAREA:  Wrap Scaffold to prevent widgets leaking into unwanted areas.


// * NULL SAFETY
// ? <var>?:    A `?` after a variable makes it "nullable".

// ? <var>!:    A `!` after a variable ensure the compiler than a "nullable" element
// ?            isn't null.


// * INTERACTIVITY
// ? GESTURE-DETECTOR:  Enables gesture detection over any widget/

// ? INKWELL:           Enables gesture detection with splash effect.


// * BUTTONS

// ? CLOSE-BUTTON
// ? BACK-BUTTON
// ? FILLED BUTTON


// * PAGE NAVIGATION

// ? NAVIGATOR.PUSH:  Use MaterialPageRoute, which expects a Scaffold!!!


/*
? ORDER
1. Stateless (Screen won't change/refresh)
2. [return] Material App (Theme of the Application)
3. [home:] Scaffold (Home/Skeleton of the Application)
**/