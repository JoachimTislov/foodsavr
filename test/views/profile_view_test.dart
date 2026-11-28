import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foodsavr/controllers/user_controller.dart';
import 'package:foodsavr/interfaces/i_auth_service.dart';
import 'package:foodsavr/service_locator.dart';
import 'package:foodsavr/views/profile_view.dart';
import 'package:logger/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mocktail/mocktail.dart';

import '../helpers/test_translation_loader.dart';

class _MockUserController extends Mock
    with ChangeNotifier
    implements UserController {}

class _MockAuthService extends Mock implements IAuthService {}

class _MockUser extends Mock implements User {}

class _MockUserInfo extends Mock implements UserInfo {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  EasyLocalization.logger.enableBuildModes = [];
  EasyLocalization.logger.enableLevels = [];

  late _MockUserController mockController;
  late _MockAuthService mockAuthService;
  late _MockUser mockUser;
  late TestTranslationLoader translations;

  void useProviders(List<String> providerIds) {
    final providers = [
      for (final id in providerIds) _MockUserInfo()..stubProvider(id),
    ];
    when(() => mockUser.providerData).thenReturn(providers);
  }

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
    translations = TestTranslationLoader();
    getIt.registerSingleton<Logger>(Logger(level: Level.off));
    mockController = _MockUserController();
    when(() => mockController.isAnonymous).thenReturn(false);
    when(() => mockController.displayName).thenReturn('Test User');
    when(() => mockController.email).thenReturn('test@test.com');
    when(() => mockController.photoUrl).thenReturn(null);
    when(() => mockController.isLoading).thenReturn(false);
    when(() => mockController.errorMessage).thenReturn(null);
    when(() => mockController.successMessage).thenReturn(null);
    mockUser = _MockUser();
    when(() => mockUser.isAnonymous).thenReturn(false);
    when(() => mockUser.email).thenReturn('test@test.com');
    useProviders(['password']);
    when(() => mockController.user).thenReturn(mockUser);
    getIt.registerSingleton<UserController>(mockController);
    mockAuthService = _MockAuthService();
    when(() => mockAuthService.currentUser).thenReturn(mockUser);
    getIt.registerSingleton<IAuthService>(mockAuthService);
  });

  Future<void> pumpProfile(WidgetTester tester) async {
    await tester.pumpWidget(
      EasyLocalization(
        supportedLocales: const [Locale('en')],
        path: 'assets/translations',
        assetLoader: translations,
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

  testWidgets('a password account can reset its password', (tester) async {
    when(
      () => mockAuthService.sendPasswordResetEmail(any()),
    ).thenAnswer((_) async {});
    await pumpProfile(tester);

    expect(find.text('Add password'), findsNothing);
    await tester.tap(find.text('Forgot Password'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Send reset link'));
    await tester.pumpAndSettle();

    verify(
      () => mockAuthService.sendPasswordResetEmail('test@test.com'),
    ).called(1);
    expect(
      find.text('Password reset email sent. Check your inbox.'),
      findsOneWidget,
    );
  });

  testWidgets('a social account is offered Add password', (tester) async {
    useProviders(['google.com']);
    await pumpProfile(tester);

    expect(find.text('Add password'), findsOneWidget);
    expect(find.text('Forgot Password'), findsNothing);
  });

  testWidgets('a guest has no password action', (tester) async {
    when(() => mockController.isAnonymous).thenReturn(true);
    when(() => mockUser.isAnonymous).thenReturn(true);
    await pumpProfile(tester);

    expect(find.text('Add password'), findsNothing);
    expect(find.text('Forgot Password'), findsNothing);
    expect(find.text('Create account'), findsOneWidget);
  });

  testWidgets('hides two-factor auth and the avatar edit icon', (tester) async {
    await pumpProfile(tester);

    expect(find.textContaining('Two-factor'), findsNothing);
    expect(find.byIcon(Icons.security), findsNothing);
    expect(find.byIcon(Icons.edit), findsNothing);
    expect(find.byType(CircleAvatar), findsOneWidget);
  });

  testWidgets('changing the email shows feedback and calls the controller', (
    tester,
  ) async {
    when(
      () => mockController.changeEmail(
        currentPassword: any(named: 'currentPassword'),
        newEmail: any(named: 'newEmail'),
      ),
    ).thenAnswer((_) async {
      when(() => mockController.errorMessage).thenReturn('Something broke');
    });
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
    expect(find.text('Something broke'), findsOneWidget);
  });
}

extension on _MockUserInfo {
  void stubProvider(String id) => when(() => providerId).thenReturn(id);
}
