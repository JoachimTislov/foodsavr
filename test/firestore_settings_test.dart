import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foodsavr/register_module.dart';

void main() {
  test('web enables persistence with multi-tab sync', () {
    final settings = firestoreSettings(isWeb: true);
    expect(settings.persistenceEnabled, isTrue);
    expect(
      settings.webPersistentTabManager,
      isA<WebPersistentMultipleTabManager>(),
    );
  });

  test('mobile enables persistence', () {
    final settings = firestoreSettings(isWeb: false);
    expect(settings.persistenceEnabled, isTrue);
    expect(settings.webPersistentTabManager, isNull);
  });
}
