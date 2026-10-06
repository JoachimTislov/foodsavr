import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foodsavr/controllers/user_controller.dart';
import 'package:foodsavr/service_locator.dart';
import 'package:foodsavr/views/profile_view.dart';
import 'package:logger/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mocktail/mocktail.dart';

class _MockUserController extends Mock
    with ChangeNotifier
    implements UserController {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  EasyLocalization.logger.enableBuildModes = [];
  EasyLocalization.logger.enableLevels = [];

  late _MockUserController mockController;

  setUpAll(() {
    final binding = TestWidgetsFlutterBinding.ensureInitialized();
    binding.platformDispatcher.views.first.physicalSize = const Size(
      1200,
      1800,
    );
    binding.platformDispatcher.views.first.devicePixelRatio = 1.0;
  });

  setUp(() async {
    await getIt.reset();
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
    getIt.registerSingleton<Logger>(Logger(level: Level.off));
    mockController = _MockUserController();
    when(() => mockController.isAnonymous).thenReturn(false);
    when(() => mockController.displayName).thenReturn('Test User');
    when(() => mockController.email).thenReturn('test@test.com');
    when(() => mockController.photoUrl).thenReturn(null);
    when(() => mockController.isLoading).thenReturn(false);
    when(() => mockController.errorMessage).thenReturn(null);
    when(() => mockController.successMessage).thenReturn(null);
    getIt.registerSingleton<UserController>(mockController);
  });

  Future<void> pumpProfile(WidgetTester tester) async {
    await tester.pumpWidget(
      EasyLocalization(
        supportedLocales: const [Locale('en')],
        path: 'assets/translations',
        fallbackLocale: const Locale('en'),
        child: Builder(
          builder: (context) => MaterialApp(
            localizationsDelegates: context.localizationDelegates,
            supportedLocales: context.supportedLocales,
            home: const ProfileView(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('profile auth actions show feedback and call controller', (
    tester,
  ) async {
    when(() => mockController.forgotPassword(any())).thenAnswer((_) async {});
    await pumpProfile(tester);

    await tester.tap(find.text('Forgot Password'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Please enter your email to reset password.'));
    await tester.pumpAndSettle();

    verify(() => mockController.forgotPassword('test@test.com')).called(1);

    when(
      () => mockController.changeEmail(
        currentPassword: any(named: 'currentPassword'),
        newEmail: any(named: 'newEmail'),
      ),
    ).thenAnswer((_) async {});

    await pumpProfile(tester);

    await tester.tap(find.text('Change Email'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextField, 'Password'),
      'password',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'New Email Address'),
      'new@test.com',
    );
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    verify(
      () => mockController.changeEmail(
        currentPassword: 'password',
        newEmail: 'new@test.com',
      ),
    ).called(1);

    when(() => mockController.forgotPassword(any())).thenAnswer((_) async {
      when(
        () => mockController.successMessage,
      ).thenReturn('Password reset email sent. Check your inbox.');
    });
    await pumpProfile(tester);

    await tester.tap(find.text('Forgot Password'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Please enter your email to reset password.'));
    await tester.pumpAndSettle();

    expect(
      find.text('Password reset email sent. Check your inbox.'),
      findsOneWidget,
    );

    tester
        .state<ScaffoldMessengerState>(find.byType(ScaffoldMessenger))
        .clearSnackBars();
    when(() => mockController.successMessage).thenReturn(null);
    when(() => mockController.forgotPassword(any())).thenAnswer((_) async {
      when(
        () => mockController.errorMessage,
      ).thenReturn('Something went wrong');
    });
    await pumpProfile(tester);

    await tester.tap(find.text('Forgot Password'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Please enter your email to reset password.'));
    await tester.pumpAndSettle();

    expect(find.text('Something went wrong'), findsOneWidget);
  });
}
