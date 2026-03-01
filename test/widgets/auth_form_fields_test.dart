import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foodsavr/widgets/auth/auth_form_fields.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  EasyLocalization.logger.enableBuildModes = [];
  EasyLocalization.logger.enableLevels = [];

  testWidgets('toggles password visibility without setState', (tester) async {
    await EasyLocalization.ensureInitialized();

    final emailController = TextEditingController();
    final passwordController = TextEditingController();

    await tester.pumpWidget(
      EasyLocalization(
        supportedLocales: const [Locale('en', 'US')],
        path: 'assets/translations',
        fallbackLocale: const Locale('en', 'US'),
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
    await tester.pumpAndSettle();

    final passwordFieldBefore = tester.widgetList<TextFormField>(
      find.byType(TextFormField),
    ).last;
    expect(passwordFieldBefore.obscureText, isTrue);

    await tester.tap(find.byIcon(Icons.visibility_off));
    await tester.pump();

    final passwordFieldAfter = tester.widgetList<TextFormField>(
      find.byType(TextFormField),
    ).last;
    expect(passwordFieldAfter.obscureText, isFalse);

    emailController.dispose();
    passwordController.dispose();
  });
}
