import 'package:flutter_test/flutter_test.dart';
import 'package:foodsavr/features/third_party_integration/models/connection_model.dart';
import 'package:foodsavr/features/third_party_integration/models/provider_model.dart';
import 'package:foodsavr/features/third_party_integration/oauth_controller.dart';
import 'package:foodsavr/features/third_party_integration/interfaces/i_oauth_service.dart';
import 'package:logger/logger.dart';
import 'package:mocktail/mocktail.dart';
import 'package:webview_flutter/webview_flutter.dart';

class _MockGroceryStoreAuthService extends Mock implements IOAuthService {}

class _MockLogger extends Mock implements Logger {}

class _MockWebViewController extends Mock implements WebViewController {}

void main() {
  late _MockGroceryStoreAuthService authService;
  late OAuthController controller;
  late _MockWebViewController webViewController;

  setUp(() {
    authService = _MockGroceryStoreAuthService();
    webViewController = _MockWebViewController();
    controller = OAuthController(authService, _MockLogger());
    when(() => authService.webViewController).thenReturn(webViewController);
  });

  // test('connect stores readable error message on failure', () async {
  //   final exception = Exception('Provider configuration is missing.');
  //   when(() => authService.authorize(Provider.coop)).thenThrow(exception);
  //
  //   await controller.connect(Provider.coop);
  //
  //   expect(controller.activeProvider, isNull);
  //   expect(controller.errorMessage, 'Failed to connect grocery provider');
  //   verify(() => authService.authorize(Provider.coop)).called(1);
  //   verifyNever(() => authService.getConnections());
  // });

  test('connect success flow updates connections', () async {
    const provider = Provider.coop;
    final connections = [
      Connection(
        provider: provider,
        accessToken: 'token',
        refreshToken: 'refresh',
        idToken: 'id',
        accessTokenExpiration: DateTime.now().add(const Duration(hours: 1)),
      ),
    ];

    when(() => authService.authorize(any())).thenAnswer((_) async => {});
    when(
      () => authService.fetchUserProfile(provider),
    ).thenAnswer((_) async => {});
    when(
      () => authService.getConnections(),
    ).thenAnswer((_) async => connections);

    await controller.connect(provider);

    expect(controller.connections, connections);
    expect(controller.errorMessage, isNull);
    expect(controller.activeProvider, isNull);
    verify(() => authService.authorize(any())).called(1);
    verify(() => authService.fetchUserProfile(provider)).called(1);
    verify(() => authService.getConnections()).called(1);
  });

  test('loadConnections updates connections list', () async {
    final connections = [
      const Connection(
        provider: Provider.coop,
        accessToken: 'token',
        refreshToken: 'refresh',
        idToken: 'id',
        accessTokenExpiration: null,
      ),
    ];
    when(
      () => authService.getConnections(),
    ).thenAnswer((_) async => connections);

    await controller.loadConnections();

    expect(controller.connections, connections);
    verify(() => authService.getConnections()).called(1);
  });
}
