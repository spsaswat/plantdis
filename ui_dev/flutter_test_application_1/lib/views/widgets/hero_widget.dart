import 'package:flutter/material.dart';
import 'package:flutter_test_application_1/data/notifiers.dart';

class HeroWidget extends StatelessWidget {
  const HeroWidget({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Hero(
          tag: 'hero1',
          child: ValueListenableBuilder(
            valueListenable: isDarkModeNotifier,
            builder: (context, isDarkMode, child) {
              return AspectRatio(
                aspectRatio: 1920 / 1080,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(5.0),
                  child: Image.asset(
                    'assets/images/background.jpg',
                    color: Colors.white,
                    colorBlendMode:
                        isDarkMode ? BlendMode.exclusion : BlendMode.softLight,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
              );
            },
          ),
        ),
        FittedBox(
          child: ValueListenableBuilder(
            valueListenable: isDarkModeNotifier,
            builder: (context, isDarkMode, child) {
              return Text(
                title,
                style: TextStyle(
                  color: isDarkMode ? Colors.white70 : Colors.black87,
                  fontSize: 100.0,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 50.0,
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
