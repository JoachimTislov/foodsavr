// ignore_for_file: depend_on_referenced_packages

import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foodsavr/controllers/dashboard_controller.dart';
import 'package:foodsavr/controllers/preferences_controller.dart';
import 'package:foodsavr/controllers/user_controller.dart';
import 'package:foodsavr/features/third_party_integration/oauth_controller.dart';
import 'package:foodsavr/features/third_party_integration/services/oauth_service.dart';
import 'package:foodsavr/services/secure_storage_service.dart';
import 'package:foodsavr/views/settings_view.dart';
import 'package:foodsavr/widgets/common/app_navigation_rail.dart';
import 'package:foodsavr/interfaces/i_auth_service.dart';
import 'package:foodsavr/interfaces/i_collection_repository.dart'; // Explicitly import ICollectionRepository
import 'package:foodsavr/interfaces/i_product_repository.dart';
import 'package:foodsavr/interfaces/i_validator.dart'; // Added IValidator import
import 'package:foodsavr/models/collection_model.dart'; // Added Collection model import
import 'package:foodsavr/models/product_model.dart'; // Added Product model import
import 'package:foodsavr/routes/go_router.dart';
import 'package:foodsavr/service_locator.dart';
import 'package:foodsavr/services/web_access.dart';
import 'package:foodsavr/views/auth_view.dart';
import 'package:foodsavr/views/delete_account_view.dart';
import 'package:foodsavr/views/legal_document_view.dart';
import 'package:foodsavr/views/web_access_view.dart';
import 'package:foodsavr/services/collection_service.dart'; // Import CollectionService
import 'package:foodsavr/services/barcode_lookup_queue.dart';
import 'package:foodsavr/services/product_service.dart';
import 'package:foodsavr/services/sync_status.dart';
import 'package:foodsavr/utils/shelf_life.dart';
import 'package:foodsavr/utils/theme_notifier.dart';
import 'package:foodsavr/views/dashboard_view.dart';
import 'package:foodsavr/views/landing_page_view.dart';
import 'package:go_router/go_router.dart';
import 'package:logger/logger.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'helpers/fake_receipt_repository.dart';
import 'helpers/in_memory_preferences_repository.dart';

class _MockSecureStorage extends Mock implements SecureStorage {}

class _MockShelfLifeService extends Mock implements ShelfLifeService {}

class _MockIValidatorProduct extends Mock implements IValidator<Product> {}

class _MockIValidatorCollection extends Mock
    implements IValidator<Collection> {}

class _FakeCollectionRepository extends Mock implements ICollectionRepository {}

// Simplified _MockUser and _MockUserCredential
class _MockUser extends Mock implements User {
  @override
  String get uid => 'test_uid';
  @override
  bool get isAnonymous => false;
  @override
  List<UserInfo> get providerData => [];
  @override
  String? get displayName => 'Test User';
  @override
  String? get email => 'test@example.com';
  @override
  String? get photoURL => null;
}

class _MockUserCredential extends Mock implements UserCredential {
  @override
  User? get user => _MockUser();
}

class _FakeProductRepository extends Mock implements IProductRepository {}

class _FakeAuthService implements IAuthService {
  late final StreamController<User?> _controller =
      StreamController<User?>.broadcast(
        onListen: () {
          _controller.add(_userId != null ? _MockUser() : null);
        },
      );
  String? _userId;

  void signInForTest(String userId) {
    _userId = userId;
    _controller.add(_MockUser());
  }

  @override
  Stream<User?> get authStateChanges => _controller.stream;

  @override
  User? get currentUser => null;

  @override
  String? getUserId() => _userId == null ? null : _MockUser().uid;
  @override
  Future<UserCredential> signIn({
    required String email,
    required String password,
    bool rememberMe = false,
  }) async {
    signInForTest('test-user');
    return _MockUserCredential();
  }

  @override
  Future<UserCredential> signUp({
    required String email,
    required String password,
  }) async {
    signInForTest('test-user');
    return _MockUserCredential();
  }

  @override
  Future<void> deleteAccount({
    bool reauthenticate = false,
    String? password,
  }) async {
    if (!reauthenticate) {
      throw FirebaseAuthException(code: 'requires-recent-login');
    }
    await signOut();
  }

  @override
  Future<void> signOut() async {
    _userId = null;
    _controller.add(null);
  }

  Future<void> dispose() async {
    await _controller.close();
  }

  @override
  Future<UserCredential> signInWithFacebook() {
    throw UnimplementedError();
  }

  @override
  Future<UserCredential> signInWithGoogle() {
    throw UnimplementedError();
  }

  @override
  Future<UserCredential> signInAsGuest() {
    signInForTest('test-user');
    return Future.value(_MockUserCredential());
  }

  @override
  Future<void> sendPasswordResetEmail(String email) {
    throw UnimplementedError();
  }

  @override
  Future<void> changeEmail({
    required String currentPassword,
    required String newEmail,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<void> linkPasswordCredential({
    required String email,
    required String password,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<void> linkGoogleProvider() {
    throw UnimplementedError();
  }

  @override
  Future<void> linkFacebookProvider() {
    throw UnimplementedError();
  }
}

class _TestApp extends StatelessWidget {
  final GoRouter router;

  const _TestApp({required this.router});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      localizationsDelegates: context.localizationDelegates,
      supportedLocales: context.supportedLocales,
      locale: context.locale,
      routerConfig: router,
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  EasyLocalization.logger.enableBuildModes = [];
  EasyLocalization.logger.enableLevels = [];
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  messenger.setMockMessageHandler('flutter/lifecycle', (_) async => null);

  group('Auth routing regression', () {
    late _FakeAuthService authService;
    late UserController userController;
    late GoRouter router;
    late _MockIValidatorProduct mockProductValidator;
    late _MockIValidatorCollection mockCollectionValidator;

    setUp(() async {
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.withData({});
      final prefs = await SharedPreferencesWithCache.create(
        cacheOptions: const SharedPreferencesWithCacheOptions(),
      );
      SharedPreferences.setMockInitialValues({});
      await EasyLocalization.ensureInitialized();
      await getIt.reset();
      authService = _FakeAuthService();
      mockProductValidator = _MockIValidatorProduct();
      mockCollectionValidator = _MockIValidatorCollection();

      getIt.registerSingleton<SharedPreferencesWithCache>(prefs);
      getIt.registerSingleton<ThemeNotifier>(ThemeNotifier(prefs));
      getIt.registerSingleton<IAuthService>(authService);
      final logger = Logger(level: Level.off);
      getIt.registerSingleton<Logger>(logger);
      getIt.registerSingleton<SyncStatus>(SyncStatus(logger));
      getIt.registerSingleton<BarcodeLookupQueue>(BarcodeLookupQueue.memory());
      getIt.registerLazySingleton<OAuthController>(
        () =>
            OAuthController(OAuthService(logger, _MockSecureStorage()), logger),
      );

      userController = UserController(
        authService,
        Logger(level: Level.off),
        translate: (String key) => key,
      );
      router = createAppRouter(authService, userController);
      getIt.registerLazySingleton<ProductService>(
        () => ProductService(
          _FakeProductRepository(),
          mockProductValidator,
          _MockShelfLifeService(),
          Logger(level: Level.off),
        ),
      );
      final collections = _FakeCollectionRepository();
      when(() => collections.getCollections(any())).thenAnswer((_) async => []);
      getIt.registerLazySingleton<CollectionService>(
        () => CollectionService(
          collections,
          mockCollectionValidator,
          Logger(level: Level.off),
        ),
      );
      getIt.registerFactory<UserController>(
        () => UserController(authService, Logger(level: Level.off)),
      );
      getIt.registerLazySingleton<PreferencesController>(
        () => PreferencesController(
          authService,
          InMemoryPreferencesRepository(),
          getIt<CollectionService>(),
          logger,
        ),
      );
      getIt.registerLazySingleton<DashboardController>(
        () => DashboardController(
          authService,
          getIt<ProductService>(),
          getIt<CollectionService>(),
          getIt<PreferencesController>(),
          FakeReceiptRepository(),
          Logger(level: Level.off),
        ),
      );
    });

    tearDown(() async {
      router.dispose();
      await authService.dispose();
      await getIt.reset();
      rootBundle.clear();
    });

    testWidgets('public routes and deletion sign-in bypass the web code', (
      tester,
    ) async {
      final onError = FlutterError.onError;
      FlutterError.onError = (details) {
        if (details.exceptionAsString().contains('A RenderFlex overflowed')) {
          return;
        }
        onError?.call(details);
      };
      addTearDown(() => FlutterError.onError = onError);
      tester.view.physicalSize = const Size(1200, 1800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final prefs = getIt<SharedPreferencesWithCache>();
      final access = WebAccess('fixture-code', prefs);
      addTearDown(access.dispose);
      router.dispose();
      router = createAppRouter(authService, userController, webAccess: access);
      await tester.pumpWidget(
        EasyLocalization(
          supportedLocales: const [Locale('en'), Locale('nb')],
          path: 'assets/translations',
          fallbackLocale: const Locale('en'),
          child: _TestApp(router: router),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(WebAccessView), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'wrong');
      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();
      expect(find.text('That code is incorrect.'), findsOneWidget);

      for (final path in ['/privacy', '/terms']) {
        router.go(path);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        expect(find.byType(LegalDocumentView), findsOneWidget);
      }
      router.go('/delete-account');
      await tester.pumpAndSettle();
      expect(
        find.text('Sign in to the account you want to delete.'),
        findsOneWidget,
      );
      await tester.tap(find.text('Sign in'));
      await tester.pumpAndSettle();
      expect(find.byType(AuthView), findsOneWidget);

      authService.signInForTest('uid-123');
      await tester.pumpAndSettle();
      expect(find.byType(DeleteAccountView), findsOneWidget);
      expect(find.text('Delete Account'), findsNWidgets(2));

      router.go('/dashboard');
      await tester.pumpAndSettle();
      expect(find.byType(WebAccessView), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'fixture-code');
      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();
      expect(find.byType(DashboardView), findsOneWidget);

      router.go('/settings');
      await tester.pumpAndSettle();
      expect(find.byType(AppNavigationRail), findsOneWidget);
      expect(find.widgetWithText(SettingsView, 'BEHAVIOR'), findsOneWidget);

      final remembered = WebAccess('fixture-code', prefs);
      final rotated = WebAccess('new-fixture-code', prefs);
      addTearDown(remembered.dispose);
      addTearDown(rotated.dispose);
      expect(remembered.isLocked, isFalse);
      expect(rotated.isLocked, isTrue);
      expect(remembered.unlock(' fixture-code '), isTrue);
      final spaced = WebAccess(' spaced-code ', prefs);
      addTearDown(spaced.dispose);
      expect(spaced.unlock('spaced-code'), isFalse);
      expect(spaced.unlock(' spaced-code '), isTrue);
      router.go('/delete-account');
      await tester.pumpAndSettle();
      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();
      await tester.tap(
        find.widgetWithText(FilledButton, 'Yes, Delete Account'),
      );
      await tester.pumpAndSettle();
      expect(find.text('Your account was deleted.'), findsNothing);
      await tester.tap(find.text('Verify and delete'));
      await tester.pumpAndSettle();
      expect(find.text('Your account was deleted.'), findsOneWidget);
      await tester.tap(find.text('Back to FoodSavr'));
      await tester.pumpAndSettle();
      expect(find.byType(LandingPageView), findsOneWidget);
      expect(find.text('Get started'), findsOneWidget);

      authService.signInForTest('uid-123');
      await tester.pumpAndSettle();
      expect(find.byType(DashboardView), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets(
      'canonical paths, legacy aliases, and # hash URLs open legal and delete-account modals',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 1800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        router.dispose();
        router = createAppRouter(
          authService,
          userController,
          initialUri: Uri.parse('https://lettmat.app/#/legal/terms'),
        );

        await tester.pumpWidget(
          EasyLocalization(
            supportedLocales: const [Locale('en'), Locale('nb')],
            path: 'assets/translations',
            fallbackLocale: const Locale('en'),
            child: _TestApp(router: router),
          ),
        );
        await tester.pumpAndSettle();

        expect(router.routeInformationProvider.value.uri.path, '/legal/terms');
        expect(find.byType(LegalDocumentView), findsOneWidget);

        for (final (input, expectedPath, isLegal) in const [
          ('/legal/privacy', '/legal/privacy', true),
          ('/privacy', '/legal/privacy', true),
          ('/#/legal/privacy', '/legal/privacy', true),
          ('/#/privacy', '/legal/privacy', true),
          ('/legal/terms', '/legal/terms', true),
          ('/terms', '/legal/terms', true),
          ('/#/terms', '/legal/terms', true),
          ('/account/delete', '/account/delete', false),
          ('/delete-account', '/account/delete', false),
          ('/#/account/delete', '/account/delete', false),
          ('/#/delete-account', '/account/delete', false),
        ]) {
          router.go(input);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 500));
          expect(
            router.routeInformationProvider.value.uri.path,
            expectedPath,
            reason: 'input $input should resolve to $expectedPath',
          );
          if (isLegal) {
            expect(find.byType(LegalDocumentView), findsOneWidget);
          } else {
            expect(find.byType(DeleteAccountView), findsOneWidget);
          }
          expect(find.byType(Dialog), findsOneWidget);
        }

        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  });

  tearDownAll(() {
    messenger.setMockMessageHandler('flutter/lifecycle', null);
  });
}
