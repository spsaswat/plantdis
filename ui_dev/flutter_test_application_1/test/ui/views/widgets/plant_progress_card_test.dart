import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test_application_1/views/widgets/plant_progress_card.dart';

void main() {
  testWidgets('PlantProgressCard basic structure test', (WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: PlantProgressCard(plantId: 'test_plant_id'),
      ),
    ));

    await tester.pumpAndSettle();

    // test basic UI structure
    expect(find.byType(Card), findsOneWidget);
    expect(find.textContaining('Plant ID'), findsOneWidget);
    expect(find.byIcon(Icons.image_not_supported_outlined), findsOneWidget);
  });

  testWidgets('PlantProgressCard shows correct plant ID', (WidgetTester tester) async {
    const testPlantId = 'unique_test_id_123';
    
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: PlantProgressCard(plantId: testPlantId),
      ),
    ));

    await tester.pumpAndSettle();

    expect(find.textContaining(testPlantId), findsOneWidget);
  });

  testWidgets('PlantProgressCard has image thumbnail area', (WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: PlantProgressCard(plantId: 'test_plant_id'),
      ),
    ));

    await tester.pumpAndSettle();

    expect(find.byType(ClipRRect), findsOneWidget);
    expect(find.byType(SizedBox), findsWidgets);
  });
}
