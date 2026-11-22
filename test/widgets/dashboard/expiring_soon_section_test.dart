import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foodsavr/controllers/preferences_controller.dart';
import 'package:foodsavr/interfaces/i_auth_service.dart';
import 'package:foodsavr/models/collection_model.dart';
import 'package:foodsavr/models/product_model.dart';
import 'package:foodsavr/routes/routes.dart';
import 'package:foodsavr/service_locator.dart';
import 'package:foodsavr/services/collection_service.dart';
import 'package:foodsavr/services/product_service.dart';
import 'package:foodsavr/widgets/dashboard/expiring_soon_section.dart';
import 'package:foodsavr/widgets/product/product_card_normal.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Auth extends Mock implements IAuthService {}

class _Products extends Mock implements ProductService {}

class _Collections extends Mock implements CollectionService {}

class _Preferences extends ChangeNotifier implements PreferencesController {
  @override
  int get expiringSoonDays => 5;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets('View all opens only expiring products in soonest-first order', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'listQuery.products.user': '{"sort":"name","status":"fresh"}',
    });
    final auth = _Auth();
    final products = _Products();
    final collections = _Collections();
    final preferences = _Preferences();
    getIt.registerSingleton<IAuthService>(auth);
    getIt.registerSingleton<ProductService>(products);
    getIt.registerSingleton<CollectionService>(collections);
    getIt.registerSingleton<PreferencesController>(preferences);
    addTearDown(getIt.reset);
    addTearDown(preferences.dispose);
    when(auth.getUserId).thenReturn('user');
    final now = DateTime.now();
    Product expires(String name, int days) => Product(
      id: name,
      name: name,
      description: '',
      userId: 'user',
      expiries: [
        ExpiryEntry(
          quantity: 1,
          expirationDate: DateTime(now.year, now.month, now.day + days),
        ),
      ],
    );

    when(() => products.getProducts('user', forceRefresh: true)).thenAnswer(
      (_) async => [
        expires('Apples', 4),
        expires('Carrots', 10),
        expires('Yogurt', 1),
        expires('Bread', -1),
      ],
    );
    when(
      () => collections.getCollectionsForUser('user'),
    ).thenAnswer((_) async => <Collection>[]);

    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => Scaffold(
            body: Column(
              children: [
                const ExpiringSoonSection(products: []),
                TextButton(
                  onPressed: () => context.push('/dashboard/product-list'),
                  child: const Text('Open inventory'),
                ),
              ],
            ),
          ),
        ),
        GoRoute(
          path: '/dashboard/product-list',
          builder: const ProductListRoute().build,
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.tap(find.text('common.viewAll'));
    await tester.pumpAndSettle();

    List<String> visibleProducts() => tester
        .widgetList<ProductCardNormal>(find.byType(ProductCardNormal))
        .map((card) => card.product.name)
        .toList();

    expect(visibleProducts(), ['Yogurt', 'Apples']);
    expect(tester.takeException(), isNull);

    router.pop();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open inventory'));
    await tester.pumpAndSettle();
    expect(visibleProducts(), ['Carrots']);
    expect(tester.takeException(), isNull);
  });
}
