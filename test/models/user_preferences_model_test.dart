import 'package:flutter_test/flutter_test.dart';
import 'package:foodsavr/models/collection_model.dart';
import 'package:foodsavr/models/user_preferences_model.dart';

Collection _inventory(String id) =>
    Collection(id: id, name: id, productIds: const [], userId: 'u');

void main() {
  group('UserPreferences', () {
    test('defaults match the pre-preferences behavior', () {
      const prefs = UserPreferences();
      expect(prefs.expiringSoonDays, 6);
      expect(prefs.defaultInventoryId, isNull);
    });

    test('JSON round trip preserves every field', () {
      const prefs = UserPreferences(
        expiringSoonDays: 3,
        defaultInventoryId: 'inv-2',
      );
      expect(UserPreferences.fromJson(prefs.toJson()), prefs);
    });

    test('empty and unknown-field JSON parse to defaults', () {
      expect(UserPreferences.fromJson({}), const UserPreferences());
      expect(
        UserPreferences.fromJson({'futureField': true, 'expiringSoonDays': 2}),
        const UserPreferences(expiringSoonDays: 2),
      );
    });

    test('effectiveExpiringSoonDays clamps out-of-range values', () {
      expect(
        const UserPreferences(expiringSoonDays: 0).effectiveExpiringSoonDays,
        1,
      );
      expect(
        const UserPreferences(expiringSoonDays: 999).effectiveExpiringSoonDays,
        30,
      );
      expect(
        const UserPreferences(expiringSoonDays: 4).effectiveExpiringSoonDays,
        4,
      );
    });

    group('resolveDefaultInventoryId', () {
      final inventories = [_inventory('a'), _inventory('b')];

      test('returns the configured inventory when it exists', () {
        const prefs = UserPreferences(defaultInventoryId: 'b');
        expect(prefs.resolveDefaultInventoryId(inventories), 'b');
      });

      test('falls back to the first inventory when unset', () {
        expect(
          const UserPreferences().resolveDefaultInventoryId(inventories),
          'a',
        );
      });

      test(
        'falls back to the first inventory when the configured one is gone',
        () {
          const prefs = UserPreferences(defaultInventoryId: 'deleted');
          expect(prefs.resolveDefaultInventoryId(inventories), 'a');
        },
      );

      test('returns null when there are no inventories', () {
        const prefs = UserPreferences(defaultInventoryId: 'b');
        expect(prefs.resolveDefaultInventoryId(const []), isNull);
      });
    });
  });
}
