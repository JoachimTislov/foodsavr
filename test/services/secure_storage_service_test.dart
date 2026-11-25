import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foodsavr/features/third_party_integration/models/provider_model.dart';
import 'package:foodsavr/services/secure_storage_service.dart';

import '../features/third_party_integration/support/fake_accounts.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const provider = Provider.rema;
  const raw = FlutterSecureStorage();
  late FakeAccounts accounts;

  SecureStorage create() => SecureStorage(raw, auth: accounts.auth);

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    accounts = FakeAccounts();
  });

  Future<void> connectAs(SecureStorage storage, String uid) async {
    await accounts.use(FakeAccounts.user(uid));
    await storage.write(provider, Key.access_token, '$uid-access');
    await storage.write(provider, Key.refresh_token, '$uid-refresh');
  }

  test('user A tokens are not readable after switching to user B', () async {
    final storage = create();
    await connectAs(storage, 'a');
    expect(await storage.read(provider, Key.access_token), 'a-access');

    await accounts.use(FakeAccounts.user('b'));

    expect(await storage.read(provider, Key.access_token), isNull);
    expect(await raw.readAll(), isEmpty);
    await storage.write(provider, Key.access_token, 'b-access');
    expect(await raw.readAll(), {'store.b.rema.access_token': 'b-access'});
  });

  test('signing out removes the account tokens from the device', () async {
    final storage = create();
    await connectAs(storage, 'a');

    await accounts.use(null);
    await storage.idle;

    expect(await raw.readAll(), isEmpty);
    expect(await storage.read(provider, Key.access_token), isNull);
    expect(
      () => storage.write(provider, Key.access_token, 'x'),
      throwsStateError,
    );
  });

  test('a null before the session is restored keeps its tokens', () async {
    FlutterSecureStorage.setMockInitialValues({
      'store.a.rema.access_token': 'a-access',
      'store.a.rema.refresh_token': 'a-refresh',
      'store.c.rema.access_token': 'stale',
    });
    final storage = create();

    await accounts.use(null);
    await storage.idle;
    expect(await raw.readAll(), hasLength(3));

    await accounts.use(FakeAccounts.user('a'));
    expect(await storage.read(provider, Key.access_token), 'a-access');
    expect(await raw.readAll(), {
      'store.a.rema.access_token': 'a-access',
      'store.a.rema.refresh_token': 'a-refresh',
    });
  });

  test('a repeated event for the same account keeps its tokens', () async {
    final storage = create();
    await connectAs(storage, 'a');

    await accounts.use(FakeAccounts.user('a'));

    expect(await storage.read(provider, Key.access_token), 'a-access');
  });

  test(
    'clearStoreTokens clears every store of the signed-in account',
    () async {
      final storage = create();
      await accounts.use(FakeAccounts.user('a'));
      await storage.write(Provider.rema, Key.access_token, 'rema');
      await storage.write(Provider.coop, Key.access_token, 'coop');

      await storage.clearStoreTokens();

      expect(await raw.readAll(), isEmpty);
    },
  );

  group('legacy unscoped tokens', () {
    setUp(() {
      FlutterSecureStorage.setMockInitialValues({
        'rema.Key.access_token': 'legacy-access',
        'rema.Key.refresh_token': 'legacy-refresh',
        'rema.Key.expires_at': DateTime.now()
            .add(const Duration(hours: 1))
            .toIso8601String(),
        'store.b.rema.access_token': 'b-access',
      });
    });

    test('are never adopted by the account that signs in', () async {
      final storage = create();
      await accounts.use(FakeAccounts.user('b'));

      expect(await storage.read(provider, Key.refresh_token), isNull);
      expect(await raw.readAll(), {'store.b.rema.access_token': 'b-access'});
    });

    test('are deleted on a first null event as well', () async {
      final storage = create();
      await accounts.use(null);
      await storage.idle;

      expect(await raw.readAll(), {'store.b.rema.access_token': 'b-access'});
    });
  });
}
