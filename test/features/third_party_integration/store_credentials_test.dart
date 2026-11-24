import 'dart:async';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foodsavr/features/third_party_integration/clients/base_client.dart';
import 'package:foodsavr/features/third_party_integration/models/provider_model.dart';
import 'package:foodsavr/features/third_party_integration/services/store_credentials.dart';
import 'package:foodsavr/services/secure_storage_service.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:logger/logger.dart';

import 'support/fake_accounts.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const provider = Provider.rema;
  const tokenUrl = 'https://store.example/token';
  late FakeAccounts accounts;
  late SecureStorage storage;
  final requests = <http.Request>[];

  StoreCredentials credentials(
    FutureOr<http.Response> Function(http.Request) handler,
  ) => StoreCredentials(
    storage,
    MockClient((request) async {
      requests.add(request);
      return handler(request);
    }),
    Logger(level: Level.off),
  );

  Future<void> connect({required Duration expiresIn}) =>
      StoreCredentials(
        storage,
        MockClient((_) async => fail('unexpected request')),
        Logger(level: Level.off),
      ).save(
        provider,
        accessToken: 'old-access',
        refreshToken: 'refresh',
        accessTokenExpiration: DateTime.now().toUtc().add(expiresIn),
      );

  setUp(() async {
    dotenv.loadFromString(
      envString:
          '''
REMA_CLIENT_ID=test
REMA_REDIRECT_URL=https://app.example/callback
REMA_TOKEN_URL=$tokenUrl
REMA_REVOCATION_URL=https://store.example/revoke
REMA_API_URL=https://api.example
REMA_RECEIPTS=/receipts
''',
    );
    FlutterSecureStorage.setMockInitialValues({});
    requests.clear();
    accounts = FakeAccounts();
    storage = SecureStorage(const FlutterSecureStorage(), auth: accounts.auth);
    await accounts.use(FakeAccounts.user('a'));
  });

  test('concurrent requests with an expired token refresh once', () async {
    await connect(expiresIn: -const Duration(minutes: 5));
    final refreshed = Completer<http.Response>();
    final subject = credentials((_) => refreshed.future);

    final tokens = Future.wait([
      for (var i = 0; i < 3; i++) subject.accessToken(provider),
    ]);
    await pumpEventQueue();
    refreshed.complete(
      http.Response(
        '{"access_token":"new-access","refresh_token":"new-refresh","expires_in":3600}',
        200,
      ),
    );

    expect(await tokens, ['new-access', 'new-access', 'new-access']);
    expect(requests, hasLength(1));
    expect(requests.single.url.toString(), tokenUrl);
    expect(requests.single.bodyFields['refresh_token'], 'refresh');
    expect(await storage.read(provider, Key.refresh_token), 'new-refresh');
  });

  test('a token that expires within the margin is refreshed first', () async {
    await connect(expiresIn: const Duration(seconds: 30));
    final subject = credentials(
      (_) => http.Response('{"access_token":"new-access"}', 200),
    );

    expect(await subject.accessToken(provider), 'new-access');
    expect(await storage.read(provider, Key.refresh_token), 'refresh');
  });

  test('a valid token is used without refreshing', () async {
    await connect(expiresIn: const Duration(hours: 1));
    final subject = credentials((_) => fail('unexpected refresh'));

    expect(await subject.accessToken(provider), 'old-access');
  });

  test(
    'a rejected refresh marks the connection as needing reconnect',
    () async {
      await connect(expiresIn: -const Duration(minutes: 5));
      final subject = credentials(
        (_) => http.Response('{"error":"invalid_grant"}', 400),
      );

      await expectLater(
        Future.wait([
          subject.accessToken(provider),
          subject.accessToken(provider),
        ]),
        throwsA(isA<StoreReconnectRequired>()),
      );
      expect(requests, hasLength(1));
      expect(await subject.reconnectRequired(provider), isTrue);
      expect(await storage.read(provider, Key.access_token), isNull);
      expect(await storage.read(provider, Key.refresh_token), isNull);
    },
  );

  test('an outage keeps the connection for a later retry', () async {
    await connect(expiresIn: -const Duration(minutes: 5));
    final outage = credentials((_) => http.Response('unavailable', 502));
    await expectLater(
      outage.accessToken(provider),
      throwsA(isA<StoreTemporarilyUnavailable>()),
    );

    final offline = credentials((_) => throw http.ClientException('offline'));
    await expectLater(
      offline.accessToken(provider),
      throwsA(isA<StoreTemporarilyUnavailable>()),
    );

    expect(await outage.reconnectRequired(provider), isFalse);
    expect(await storage.read(provider, Key.refresh_token), 'refresh');
  });

  test(
    'a refresh that finishes after an account switch is discarded',
    () async {
      await connect(expiresIn: -const Duration(minutes: 5));
      final refreshed = Completer<http.Response>();
      final subject = credentials((_) => refreshed.future);

      final token = subject.accessToken(provider);
      await pumpEventQueue();
      await accounts.use(FakeAccounts.user('b'));
      refreshed.complete(http.Response('{"access_token":"new-access"}', 200));

      await expectLater(token, throwsA(isA<StoreReconnectRequired>()));
      expect(await storage.read(provider, Key.access_token), isNull);
    },
  );

  test('HTTP 401 from the store API refreshes once and retries', () async {
    await connect(expiresIn: const Duration(hours: 1));
    final authorizations = <String?>[];
    final api = MockClient((request) async {
      if (request.url.toString() == tokenUrl) {
        return http.Response('{"access_token":"new-access"}', 200);
      }
      authorizations.add(request.headers['Authorization']);
      return request.headers['Authorization'] == 'new-access'
          ? http.Response('{"ok":true}', 200)
          : http.Response('', 401);
    });
    final client = _StoreClient(
      StoreCredentials(storage, api, Logger(level: Level.off)),
      api,
    );

    expect(await client.fetch('REMA_RECEIPTS'), {'ok': true});
    expect(authorizations, ['old-access', 'new-access']);
  });

  test('revoke calls the revocation endpoint and clears tokens', () async {
    await connect(expiresIn: const Duration(hours: 1));
    final subject = credentials((_) => http.Response('', 200));

    await subject.revoke(provider);

    expect(requests.single.url.toString(), 'https://store.example/revoke');
    expect(requests.single.bodyFields, {
      'client_id': 'test',
      'token': 'refresh',
      'token_type_hint': 'refresh_token',
    });
    expect(await storage.read(provider, Key.access_token), isNull);
    expect(await storage.read(provider, Key.refresh_token), isNull);
  });

  test('revoke clears tokens when the store is unreachable', () async {
    await connect(expiresIn: const Duration(hours: 1));
    final subject = credentials((_) => throw http.ClientException('offline'));

    await subject.revoke(provider);

    expect(await storage.read(provider, Key.access_token), isNull);
  });
}

final class _StoreClient extends Client {
  _StoreClient(StoreCredentials credentials, http.Client client)
    : super(
        Logger(level: Level.off),
        credentials,
        client,
        provider: Provider.rema,
      );
}
