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

  test('user A tokens are not readable after switching to user B', () async {
    final storage = create();
    await accounts.use(FakeAccounts.user('a'));
    await storage.write(provider, Key.access_token, 'a-access');
    expect(await storage.read(provider, Key.access_token), 'a-access');

    await accounts.use(FakeAccounts.user('b'));

    expect(await storage.read(provider, Key.access_token), isNull);
    await storage.write(provider, Key.access_token, 'b-access');
    expect(await raw.readAll(), {'store.b.rema.access_token': 'b-access'});
  });

  test('signing out removes the account tokens from the device', () async {
    final storage = create();
    await accounts.use(FakeAccounts.user('a'));
    await storage.write(provider, Key.access_token, 'access');
    await storage.write(provider, Key.refresh_token, 'refresh');

    await accounts.use(null);
    await storage.idle;

    expect(await raw.readAll(), isEmpty);
    expect(await storage.read(provider, Key.access_token), isNull);
    expect(
      () => storage.write(provider, Key.access_token, 'x'),
      throwsStateError,
    );
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
    final signedInAt = DateTime.utc(2026, 11, 1);

    void seedLegacy(DateTime expiresAt) {
      FlutterSecureStorage.setMockInitialValues({
        'rema.Key.access_token': 'legacy-access',
        'rema.Key.refresh_token': 'legacy-refresh',
        'rema.Key.expires_at': expiresAt.toIso8601String(),
      });
    }

    test('are adopted once by the restored session that issued them', () async {
      seedLegacy(signedInAt.add(const Duration(hours: 1)));
      final storage = create();
      await accounts.use(FakeAccounts.user('a', signedInAt: signedInAt));

      expect(await storage.read(provider, Key.access_token), 'legacy-access');
      expect(await storage.read(provider, Key.refresh_token), 'legacy-refresh');
      expect((await raw.readAll()).keys, everyElement(startsWith('store.a.')));
    });

    test('issued before the last sign-in are deleted', () async {
      seedLegacy(signedInAt.subtract(const Duration(minutes: 1)));
      final storage = create();
      await accounts.use(FakeAccounts.user('a', signedInAt: signedInAt));

      expect(await storage.read(provider, Key.access_token), isNull);
      expect(await raw.readAll(), isEmpty);
    });

    test('are deleted when nobody is signed in at startup', () async {
      seedLegacy(signedInAt.add(const Duration(hours: 1)));
      final storage = create();
      await accounts.use(null);
      await storage.idle;
      await accounts.use(FakeAccounts.user('a', signedInAt: signedInAt));

      expect(await storage.read(provider, Key.access_token), isNull);
      expect(await raw.readAll(), isEmpty);
    });
  });
}
