import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test_application_1/data/notifiers.dart'; 

void main() {
  group('selectedPageNotifier', () {
    test('initial value is 0', () {
      expect(selectedPageNotifier.value, 0);
    });

    test('notifies listeners when value changes', () {
      int notifyCount = 0;
      selectedPageNotifier.addListener(() {
        notifyCount++;
      });

      selectedPageNotifier.value = 1;
      selectedPageNotifier.value = 2;

      expect(notifyCount, 2);
      expect(selectedPageNotifier.value, 2);
    });
  });

  group('isDarkModeNotifier', () {
    test('initial value is true', () {
      expect(isDarkModeNotifier.value, true);
    });

    test('notifies listeners when value toggles', () {
      int notifyCount = 0;
      isDarkModeNotifier.addListener(() {
        notifyCount++;
      });

      isDarkModeNotifier.value = false;
      isDarkModeNotifier.value = true;

      expect(notifyCount, 2);
      expect(isDarkModeNotifier.value, true);
    });
  });
}
