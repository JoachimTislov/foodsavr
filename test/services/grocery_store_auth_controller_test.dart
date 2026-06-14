import 'package:flutter_test/flutter_test.dart';
import 'package:foodsavr/interfaces/is_grocery_store_oauth.dart';
import 'package:foodsavr/models/m_grocery_store.dart';
import 'package:foodsavr/models/m_grocery_store_provider.dart';
import 'package:foodsavr/controllers/c_grocery_store_auth.dart';
import 'package:logger/logger.dart';
import 'package:mocktail/mocktail.dart';

class _MockGroceryStoreAuthService extends Mock
    implements IGroceryStoreAuthService {}

class _MockLogger extends Mock implements Logger {}

void main() {
  late _MockGroceryStoreAuthService authService;
  late GroceryStoreAuthController controller;

  setUp(() {
    authService = _MockGroceryStoreAuthService();
    controller = GroceryStoreAuthController(authService, _MockLogger());
  });

  test('loadConnections populates available provider states', () async {
    when(() => authService.getConnections()).thenAnswer(
      (_) async => const [
        GroceryStoreConnection(
          provider: GroceryStoreProvider.coop,
          isAvailable: true,
          isConnected: false,
        ),
      ],
    );

    await controller.loadConnections();

    expect(controller.connections, hasLength(1));
    expect(controller.connections.single.provider, GroceryStoreProvider.coop);
    expect(controller.connections.single.isConnected, isFalse);
  });

  test(
    'connect refreshes provider list after successful authorization',
    () async {
      when(
        () => authService.authorize(GroceryStoreProvider.coop),
      ).thenAnswer((_) async {});
      when(
        () => authService.fetchUserProfile(GroceryStoreProvider.coop),
      ).thenAnswer((_) async => {'sub': '123'});
      when(() => authService.getConnections()).thenAnswer(
        (_) async => const [
          GroceryStoreConnection(
            provider: GroceryStoreProvider.coop,
            isAvailable: true,
            isConnected: true,
          ),
        ],
      );

      await controller.connect(GroceryStoreProvider.coop);

      expect(controller.activeProvider, isNull);
      expect(controller.connections.single.isConnected, isTrue);
      expect(controller.errorMessage, isNull);
    },
  );

  test('connect stores readable error message on failure', () async {
    when(
      () => authService.authorize(GroceryStoreProvider.coop),
    ).thenThrow(StateError('Provider configuration is missing.'));

    await controller.connect(GroceryStoreProvider.coop);

    expect(controller.activeProvider, isNull);
    expect(controller.errorMessage, 'Provider configuration is missing.');
  });
}
