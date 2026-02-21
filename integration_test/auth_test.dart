import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:foodsavr/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Authentication flow test', (WidgetTester tester) async {
    app.main();
    await tester.pumpAndSettle();

    // Verify app has loaded landing screen
    expect(find.byType(Scaffold), findsWidgets);

    await tester.tap(find.text('Continue with Email'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Sign up'));
    await tester.pumpAndSettle();

    // Enter email
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Email Address'),
      'test@example.com',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Password'),
      'password123',
    );

    // Agree to terms
    await tester.tap(find.byType(Checkbox));
    await tester.pumpAndSettle();

    // Tap Register
    await tester.tap(find.text('Register'));
    await tester.pumpAndSettle();

    // Assuming successful registration navigates to MainView
    // Verify we are on Main View (check for some text/widget on MainView)
    expect(
      find.text('FoodSavr'),
      findsOneWidget,
    ); // Update with actual MainView content

    // Sign Out (assuming logout button exists or simulate logout)
    // Add logic to tap logout if available in UI, otherwise just verifying successful login flow is good start.
  });
}
