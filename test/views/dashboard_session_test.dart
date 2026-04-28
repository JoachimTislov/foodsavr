import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foodsavr/interfaces/i_auth_service.dart';
import 'package:foodsavr/service_locator.dart';
import 'package:foodsavr/services/product_service.dart';
import 'package:foodsavr/services/collection_service.dart';
import 'package:foodsavr/utils/collection_types.dart';
import 'package:foodsavr/views/dashboard_view.dart';
import 'package:mocktail/mocktail.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';

class MockAuthService extends Mock implements IAuthService {}

class MockProductService extends Mock implements ProductService {}

class MockCollectionService extends Mock implements CollectionService {}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    EasyLocalization.logger.enableLevels = [];
    await initializeDateFormatting('en', null);
    await EasyLocalization.ensureInitialized();
  });

  setUp(() async {
    await getIt.reset();
    getIt.registerSingleton<IAuthService>(MockAuthService());
    getIt.registerSingleton<ProductService>(MockProductService());
    getIt.registerSingleton<CollectionService>(MockCollectionService());
  });

  testWidgets(
    'DashboardView should fetch with current user on refresh, not cached user',
    (WidgetTester tester) async {
      final authService = getIt<IAuthService>();
      final productService = getIt<ProductService>();
      final collectionService = getIt<CollectionService>();

      // Initial state: user_1 is logged in
      when(() => authService.getUserId()).thenReturn('user_1');
      when(
        () => productService.getExpiringSoon('user_1'),
      ).thenAnswer((_) async => []);
      when(
        () => collectionService.getCollectionsForUser(
          'user_1',
          type: CollectionType.inventory,
        ),
      ).thenAnswer((_) async => []);

      // Also need to stub user_2 to prevent MissingStubError during the second fetch
      when(
        () => productService.getExpiringSoon('user_2'),
      ).thenAnswer((_) async => []);
      when(
        () => collectionService.getCollectionsForUser(
          'user_2',
          type: CollectionType.inventory,
        ),
      ).thenAnswer((_) async => []);

      await tester.pumpWidget(
        EasyLocalization(
          supportedLocales: const [Locale('en')],
          path: 'assets/translations',
          child: const MaterialApp(home: Scaffold(body: DashboardView())),
        ),
      );

      // Initial fetch should use 'user_1'
      await tester.pumpAndSettle();
      verify(() => productService.getExpiringSoon('user_1')).called(1);
      verify(
        () => collectionService.getCollectionsForUser(
          'user_1',
          type: CollectionType.inventory,
        ),
      ).called(1);

      // Simulate session change: user_2 is now logged in
      when(() => authService.getUserId()).thenReturn('user_2');

      // Trigger pull-to-refresh
      await tester.fling(
        find.byType(SingleChildScrollView),
        const Offset(0.0, 300.0),
        1000.0,
      );
      await tester.pumpAndSettle();

      // Verify it fetched with 'user_2'.
      // If the view cached `_userId` in `initState`, it will incorrectly use 'user_1'
      // and this verification will fail, proving the architectural flaw.
      verify(() => productService.getExpiringSoon('user_2')).called(1);
      verify(
        () => collectionService.getCollectionsForUser(
          'user_2',
          type: CollectionType.inventory,
        ),
      ).called(1);
    },
  );
}
