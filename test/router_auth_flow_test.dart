// ignore_for_file: depend_on_referenced_packages

import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foodsavr/controllers/user_controller.dart';
import 'package:foodsavr/interfaces/i_auth_service.dart';
import 'package:foodsavr/interfaces/i_collection_repository.dart'; // Explicitly import ICollectionRepository
import 'package:foodsavr/interfaces/i_product_repository.dart';
import 'package:foodsavr/routes/go_router.dart';
import 'package:foodsavr/service_locator.dart';
import 'package:foodsavr/services/collection_service.dart'; // Import CollectionService
import 'package:foodsavr/services/product_service.dart';
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

class _MockShelfLifeService extends Mock implements ShelfLifeService {}

class _FakeCollectionRepository extends Mock implements ICollectionRepository {}

class _MockUser extends Mock implements User {}

class _MockUserCredential extends Mock implements UserCredential {}

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
  String? getUserId() => _userId;
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

      getIt.registerSingleton<SharedPreferencesWithCache>(prefs);
      getIt.registerSingleton<ThemeNotifier>(ThemeNotifier(prefs));
      getIt.registerSingleton<IAuthService>(authService);

      userController = UserController(
        authService,
        Logger(level: Level.off),
        translate: (String key) => key,
      );
      router = createAppRouter(authService, userController);
      getIt.registerLazySingleton<ProductService>(
        () => ProductService(
          _FakeProductRepository(),
          _MockShelfLifeService(),
          Logger(level: Level.off),
        ),
      );
      getIt.registerLazySingleton<CollectionService>(
        () => CollectionService(
          _FakeCollectionRepository(),
          Logger(level: Level.off),
        ),
      );
      getIt.registerFactory<UserController>(() => userController);
    });

    tearDown(() async {
      router.dispose();
      await authService.dispose();
      await getIt.reset();
    });

    testWidgets(
      'redirects from landing page to main screen after authentication',
      (tester) async {
        final originalOnError = FlutterError.onError;
        FlutterError.onError = (details) {
          final message = details.exceptionAsString();
          if (message.contains('A RenderFlex overflowed')) {
            return;
          }
          originalOnError?.call(details);
        };
        addTearDown(() {
          FlutterError.onError = originalOnError;
        });

        tester.view.physicalSize = const Size(1400, 2200);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          EasyLocalization(
            supportedLocales: const [Locale('en'), Locale('nb')],
            path: 'assets/translations',
            fallbackLocale: const Locale('en'),
            child: _TestApp(router: router),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(LandingPageView), findsOneWidget);
        expect(find.text('Continue as guest'), findsOneWidget);

        authService.signInForTest('uid-123');
        await tester.pumpAndSettle();

        expect(find.byType(DashboardView), findsOneWidget);
        expect(find.byType(LandingPageView), findsNothing);
      },
    );
  });

  tearDownAll(() {
    messenger.setMockMessageHandler('flutter/lifecycle', null);
  });
}
