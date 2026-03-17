import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foodsavr/widgets/auth/auth_form_fields.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });

  testWidgets('toggles password visibility without setState', (tester) async {
    final emailController = TextEditingController();
    final passwordController = TextEditingController();

    await tester.pumpWidget(
      EasyLocalization(
        supportedLocales: const [Locale('en')],
        path: 'assets/translations',
        fallbackLocale: const Locale('en'),
        child: MaterialApp(
          home: Scaffold(
            body: AuthFormFields(
              emailController: emailController,
              passwordController: passwordController,
            ),
          ),
        ),
      ),
    );

    // Pump enough to load localizations but not settle if it hangs
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    final passwordFieldFinder = find.byType(EditableText).last;
    final passwordFieldBefore = tester.widget<EditableText>(
      passwordFieldFinder,
    );
    expect(passwordFieldBefore.obscureText, isTrue);

    await tester.tap(find.byIcon(Icons.visibility_off));
    await tester.pump();

    final passwordFieldAfter = tester.widget<EditableText>(passwordFieldFinder);
    expect(passwordFieldAfter.obscureText, isFalse);

    emailController.dispose();
    passwordController.dispose();
  });
}
