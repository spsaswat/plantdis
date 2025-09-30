import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test_application_1/data/constants.dart'; 

void main() {
  group('KTextStyle', () {
    test('appTitle has correct properties', () {
      final style = KTextStyle.appTitle;
      expect(style.color, Colors.teal);
      expect(style.fontSize, 50.0);
      expect(style.fontWeight, FontWeight.bold);
      expect(style.letterSpacing, 15.0);
    });

    test('titleTealText is bold teal text', () {
      final style = KTextStyle.titleTealText;
      expect(style.color, Colors.teal);
      expect(style.fontSize, 18.0);
      expect(style.fontWeight, FontWeight.bold);
    });

    test('termTealText is bold teal with font size 16', () {
      final style = KTextStyle.termTealText;
      expect(style.color, Colors.teal);
      expect(style.fontSize, 16.0);
      expect(style.fontWeight, FontWeight.bold);
    });

    test('descriptionText has font size 16', () {
      final style = KTextStyle.descriptionText;
      expect(style.fontSize, 16.0);
    });
  });

  group('KKeys', () {
    test('themeModeKey constant is correct', () {
      expect(KKeys.themeModeKey, 'themeModeKey');
    });
  });
}
