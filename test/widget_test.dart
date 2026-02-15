import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// TODO: Add useful tests...
void main() {
  testWidgets('renders smoke test widget', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: Text('FoodSavr'))),
    );

    expect(find.text('FoodSavr'), findsOneWidget);
  });
}
