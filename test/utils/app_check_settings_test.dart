import 'package:flutter_test/flutter_test.dart';
import 'package:foodsavr/utils/app_check_settings.dart';

void main() {
  const typeKey = 'FlutterFire-[DEFAULT]-recaptchaType';
  const siteKey = 'FlutterFire-[DEFAULT]-recaptchaSiteKey';

  for (final oldType in ['recaptcha-v3', 'debug', 'enterprise']) {
    test('clears incompatible $oldType settings without clearing auth', () {
      final storage = {
        typeKey: oldType,
        siteKey: 'old-key',
        'firebase:authUser': 'signed-in-user',
      };
      migrateAppCheckSettings(
        (key) => storage[key],
        storage.remove,
        enterpriseSiteKey: 'new-key',
      );
      expect(storage, {'firebase:authUser': 'signed-in-user'});
    });
  }

  test('retains matching Enterprise settings', () {
    final storage = {typeKey: 'enterprise', siteKey: 'same-key'};
    migrateAppCheckSettings(
      (key) => storage[key],
      storage.remove,
      enterpriseSiteKey: 'same-key',
    );
    expect(storage, {typeKey: 'enterprise', siteKey: 'same-key'});
  });

  test('empty storage needs no migration', () {
    final storage = <String, String>{};
    migrateAppCheckSettings(
      (key) => storage[key],
      storage.remove,
      enterpriseSiteKey: 'new-key',
    );
    expect(storage, isEmpty);
  });

  test('emulator startup clears persisted providers', () {
    final storage = {typeKey: 'enterprise', siteKey: 'same-key'};
    migrateAppCheckSettings(
      (key) => storage[key],
      storage.remove,
      enterpriseSiteKey: null,
    );
    expect(storage, isEmpty);
  });
}
