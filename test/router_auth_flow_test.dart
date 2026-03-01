// ignore_for_file: depend_on_referenced_packages

import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foodsavr/interfaces/i_auth_service.dart';
import 'package:foodsavr/router.dart';
import 'package:foodsavr/service_locator.dart';
import 'package:foodsavr/services/product_service.dart';
import 'package:foodsavr/interfaces/i_product_repository.dart';
import 'package:foodsavr/interfaces/i_collection_repository.dart'; // Explicitly import ICollectionRepository
import 'package:foodsavr/models/product_model.dart';
import 'package:foodsavr/models/collection_model.dart'; // Import Collection
import 'package:foodsavr/views/landing_page_view.dart';
import 'package:foodsavr/views/dashboard_view.dart';
import 'package:foodsavr/services/collection_service.dart'; // Import CollectionService
import 'package:go_router/go_router.dart';
import 'package:logger/logger.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeCollectionRepository implements ICollectionRepository {
  @override
  Future<Collection> add(Collection entity) async => entity;

  @override
  Future<Collection?> get(String id) async => null;

  @override
  Future<List<Collection>> getAll() async => [];

  @override
  Future<void> update(Collection entity) async {}

  @override
  Future<void> delete(String id) async {}

  @override
  Future<List<Collection>> getCollections(String userId) async => [];

  @override
  Future<void> addProduct(String collectionId, int productId) async {}

  @override
  Future<void> removeProduct(String collectionId, int productId) async {}
}

class _MockUser extends Mock implements User {}

class _MockUserCredential extends Mock implements UserCredential {}

class _FakeProductRepository implements IProductRepository {
  @override
  Future<Product> add(Product entity) async => entity;
  @override
  Future<Product?> get(int id) async => null;
  @override
  Future<void> update(Product entity) async {}
  @override
  Future<void> delete(int id) async {}
  @override
  Future<List<Product>> getAll() async => [];
  @override
  Future<List<Product>> getProducts(String userId) async => [];
  @override
  Future<List<Product>> getGlobalProducts() async => [];
}

class _FakeAuthService implements IAuthService {
  final _controller = StreamController<User?>.broadcast();
  String? _userId;

  void signInForTest(String userId) {
    _userId = userId;
    _controller.add(_MockUser());
  }

  @override
  Stream<User?> get authStateChanges => _controller.stream;

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
  Future<void> sendPasswordResetEmail(String email) {
    throw UnimplementedError();
  }
}

class _TestApp extends StatelessWidget {
  final GoRouter router;

  const _TestApp({required this.router});

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      child: MaterialApp.router(
        localizationsDelegates: context.localizationDelegates,
        supportedLocales: context.supportedLocales,
        locale: context.locale,
        routerConfig: router,
      ),
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
    late GoRouter router;

    setUp(() async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      await EasyLocalization.ensureInitialized();
      await getIt.reset();
      authService = _FakeAuthService();
      router = createAppRouter(authService);
      getIt.registerLazySingleton<IAuthService>(() => authService);
      getIt.registerLazySingleton<ProductService>(
        () =>
            ProductService(_FakeProductRepository(), Logger(level: Level.off)),
      );
      getIt.registerLazySingleton<CollectionService>(
        () => CollectionService(
          _FakeCollectionRepository(),
          Logger(level: Level.off),
        ),
      );
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
            supportedLocales: const [Locale('en', 'US'), Locale('nb', 'NO')],
            path: 'assets/translations',
            fallbackLocale: const Locale('en', 'US'),
            child: _TestApp(router: router),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(LandingPageView), findsOneWidget);

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
