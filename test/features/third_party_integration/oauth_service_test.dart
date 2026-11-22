import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foodsavr/features/third_party_integration/models/provider_model.dart';
import 'package:foodsavr/features/third_party_integration/oauth_util.dart';
import 'package:foodsavr/features/third_party_integration/oauth_controller.dart';
import 'package:foodsavr/features/third_party_integration/services/oauth_service.dart';
import 'package:foodsavr/services/secure_storage_service.dart';
import 'package:http/http.dart';
import 'package:http/testing.dart';
import 'package:logger/logger.dart';
// The platform interface provides the WebView test seam.
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart'; // ignore: depend_on_referenced_packages

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const provider = Provider.rema;
  late _WebViewPlatform platform;
  late OAuthService service;

  setUp(() {
    dotenv.loadFromString(
      envString: '''
REMA_CLIENT_ID=test
REMA_REDIRECT_URL=https://app.example/callback
REMA_SCOPES=read
REMA_AUTHORIZATION_URL=https://store.example/authorize
REMA_TOKEN_URL=https://store.example/token
''',
    );
    FlutterSecureStorage.setMockInitialValues({});
    platform = _WebViewPlatform();
    WebViewPlatform.instance = platform;
    service = OAuthService(
      Logger(),
      SecureStorage(const FlutterSecureStorage()),
    );
  });

  test('rejects mismatched state before exchanging a code', () async {
    await runWithClient(() async {
      final authorization = service.authorize(provider);
      final failure = expectLater(
        authorization,
        throwsA(isA<OAuthAuthorizationException>()),
      );
      await platform.redirect(state: 'mismatched');
      await failure;
    }, () => MockClient((_) async => fail('Unexpected token exchange')));
  });

  test('uses a fresh verifier and stores a one-hour expiry', () async {
    final verifiers = <String>[];
    await runWithClient(
      () async {
        final before = DateTime.now().add(const Duration(hours: 1));
        for (var attempt = 0; attempt < 2; attempt++) {
          final authorization = service.authorize(provider);
          await platform.redirect();
          await authorization;
        }
        final after = DateTime.now().add(const Duration(hours: 1));
        final expiration = (await service.expiresAt(provider))!;
        expect(expiration.isBefore(before), isFalse);
        expect(expiration.isAfter(after), isFalse);
        expect(verifiers.toSet(), hasLength(2));
      },
      () => MockClient((request) async {
        verifiers.add(request.bodyFields['code_verifier']!);
        return Response(
          '{"access_token":"access","refresh_token":"refresh","expires_in":3600}',
          200,
        );
      }),
    );
  });

  test('reports an error when the token endpoint returns HTTP 400', () async {
    await runWithClient(
      () async {
        final controller = OAuthController(service, Logger());
        final connection = controller.connect(provider);
        await platform.redirect();
        await connection;
        expect(controller.connectionFailed, isTrue);
        expect(controller.activeProvider, isNull);
        expect(await service.expiresAt(provider), isNull);
      },
      () => MockClient((_) async => Response('{"error":"invalid_grant"}', 400)),
    );
  });

  test('allows another authorization after cancellation', () async {
    final controller = OAuthController(service, Logger());
    final first = controller.connect(provider);
    final firstState =
        platform.controller.authorizationUri.queryParameters['state'];
    controller.cancelConnection();
    await first;
    expect(controller.connectionFailed, isFalse);

    final second = controller.connect(provider);
    expect(
      platform.controller.authorizationUri.queryParameters['state'],
      isNot(firstState),
    );
    controller.cancelConnection();
    await second;
  });
}

class _WebViewPlatform extends WebViewPlatform {
  late _WebViewController controller;
  late _NavigationDelegate delegate;

  @override
  PlatformWebViewController createPlatformWebViewController(
    PlatformWebViewControllerCreationParams params,
  ) => controller = _WebViewController(params);

  @override
  PlatformNavigationDelegate createPlatformNavigationDelegate(
    PlatformNavigationDelegateCreationParams params,
  ) => delegate = _NavigationDelegate(params);

  Future<void> redirect({String? state}) async {
    final uri = Uri.https('app.example', '/callback', {
      'state': state ?? controller.authorizationUri.queryParameters['state']!,
      'code': 'test-code',
    });
    final decision = await delegate.onNavigation(
      NavigationRequest(url: uri.toString(), isMainFrame: true),
    );
    expect(decision, NavigationDecision.prevent);
  }
}

class _WebViewController extends PlatformWebViewController {
  _WebViewController(super.params) : super.implementation();

  late Uri authorizationUri;

  @override
  Future<void> loadRequest(LoadRequestParams params) async {
    authorizationUri = params.uri;
  }

  @override
  Future<void> setJavaScriptMode(JavaScriptMode mode) async {}

  @override
  Future<void> setPlatformNavigationDelegate(
    PlatformNavigationDelegate handler,
  ) async {}
}

class _NavigationDelegate extends PlatformNavigationDelegate {
  _NavigationDelegate(super.params) : super.implementation();

  late NavigationRequestCallback onNavigation;

  @override
  Future<void> setOnNavigationRequest(
    NavigationRequestCallback callback,
  ) async {
    onNavigation = callback;
  }

  @override
  Future<void> setOnWebResourceError(WebResourceErrorCallback callback) async {}
}
