// ignore_for_file: library_private_types_in_public_api
import 'package:flutter/material.dart';
import 'package:flutter_test_application_1/data/constants.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'data/notifiers.dart';
import 'views/pages/welcome_page.dart';
import '../utils/logger.dart';

// Import for tflite factories initialization
import 'package:flutter_test_application_1/services/tflite_interop/tflite_wrapper.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  setupLogging();

  // Initialize TFLite factories
  initializeTfliteFactories();

  // Initialize Firebase
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  // Use a late final Future to store the asynchronous initialization
  late final Future<void> _initFuture;

  @override
  void initState() {
    super.initState();
    _initFuture = initThemeMode();
  }

  Future<void> initThemeMode() async {
    final SharedPreferences pref = await SharedPreferences.getInstance();
    final bool? repeat = pref.getBool(KKeys.themeModeKey);
    isDarkModeNotifier.value = repeat ?? true;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _initFuture,
      builder: (context, snapshot) {
        // Check the state of the future
        if (snapshot.connectionState == ConnectionState.done) {
          // Future is complete, now we can build the actual app
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
                home: const WelcomePage(),
              );
            },
          );
        } else {
          // Future is still running, show a loading screen
          return const Center(child: CircularProgressIndicator());
        }
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