import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart' hide Key;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foodsavr/features/third_party_integration/models/provider_model.dart';
import 'package:foodsavr/features/third_party_integration/oauth_controller.dart';
import 'package:foodsavr/features/third_party_integration/services/oauth_service.dart';
import 'package:foodsavr/features/third_party_integration/services/store_credentials.dart';
import 'package:foodsavr/features/third_party_integration/widgets/connections_list.dart';
import 'package:foodsavr/services/secure_storage_service.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:foodsavr/features/third_party_integration/interfaces/i_oauth_service.dart';
import 'package:logger/logger.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart'; // ignore: depend_on_referenced_packages

import '../../helpers/test_translation_loader.dart';
import 'support/fake_accounts.dart';
import 'support/fake_web_view_platform.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  EasyLocalization.logger.enableBuildModes = [];
  EasyLocalization.logger.enableLevels = [];
  final logger = Logger(level: Level.off);
  late SecureStorage storage;
  late StoreCredentials credentials;
  late OAuthController controller;
  final revocations = <http.Request>[];

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
    dotenv.loadFromString(
      envString: '''
REMA_CLIENT_ID=test
REMA_REDIRECT_URL=https://app.example/callback
REMA_TOKEN_URL=https://store.example/token
REMA_REVOCATION_URL=https://store.example/revoke
''',
    );
  });

  /// Builds the subject inside the test zone so storage futures run on the
  /// fake clock.
  Future<void> arrange() async {
    FlutterSecureStorage.setMockInitialValues({});
    WebViewPlatform.instance = FakeWebViewPlatform();
    revocations.clear();
    final accounts = FakeAccounts();
    storage = SecureStorage(const FlutterSecureStorage(), auth: accounts.auth);
    credentials = StoreCredentials(
      storage,
      MockClient((request) async {
        revocations.add(request);
        return http.Response('', 200);
      }),
      logger,
    );
    controller = OAuthController(
      OAuthService(logger, storage, credentials: credentials),
      logger,
    );
    await accounts.use(FakeAccounts.user('a'));
  }

  Future<void> pumpList(WidgetTester tester) async {
    await tester.pumpWidget(
      EasyLocalization(
        supportedLocales: const [Locale('en')],
        path: 'assets/translations',
        assetLoader: TestTranslationLoader(),
        fallbackLocale: const Locale('en'),
        child: Builder(
          builder: (context) => MaterialApp(
            localizationsDelegates: context.localizationDelegates,
            supportedLocales: context.supportedLocales,
            locale: context.locale,
            home: Scaffold(
              body: SingleChildScrollView(
                child: OAuthConnectionsList(controller: controller),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('a connected store disconnects after confirmation', (
    tester,
  ) async {
    await arrange();
    await credentials.save(
      Provider.rema,
      accessToken: 'access',
      refreshToken: 'refresh',
      accessTokenExpiration: DateTime.now().toUtc().add(
        const Duration(hours: 1),
      ),
    );
    await pumpList(tester);

    expect(find.text('Connected'), findsOneWidget);
    final disconnect = find.widgetWithText(OutlinedButton, 'Disconnect');
    expect(tester.widget<OutlinedButton>(disconnect).enabled, isTrue);

    await tester.tap(disconnect);
    await tester.pumpAndSettle();
    expect(find.text('Disconnect Rema?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Disconnect'));
    await tester.pumpAndSettle();

    expect(revocations.single.bodyFields['token'], 'refresh');
    expect(await storage.read(Provider.rema, Key.access_token), isNull);
    expect(await storage.read(Provider.rema, Key.refresh_token), isNull);
    expect(find.text('Connected'), findsNothing);
  });

  testWidgets('cancelling the confirmation keeps the connection', (
    tester,
  ) async {
    await arrange();
    await credentials.save(
      Provider.rema,
      accessToken: 'access',
      refreshToken: 'refresh',
    );
    await pumpList(tester);

    await tester.tap(find.widgetWithText(OutlinedButton, 'Disconnect'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pumpAndSettle();

    expect(revocations, isEmpty);
    expect(await storage.read(Provider.rema, Key.access_token), 'access');
  });

  testWidgets('a revoked connection asks to reconnect', (tester) async {
    await arrange();
    await storage.write(
      Provider.rema,
      Key.reconnect_reason,
      StoreCredentials.revokedReason,
    );
    await pumpList(tester);

    expect(find.text('Sign-in expired'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Reconnect'), findsOneWidget);
  });

  testWidgets('no available stores shows a localized fallback', (tester) async {
    await arrange();
    final service = _MockOAuthService();
    when(service.getConnections).thenAnswer((_) async => []);
    controller = OAuthController(service, logger);
    await pumpList(tester);

    expect(
      find.text('No grocery integrations are available on this device.'),
      findsOneWidget,
    );
  });
}

class _MockOAuthService extends Mock implements IOAuthService {}
