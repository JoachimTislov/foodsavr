import 'package:flutter_test/flutter_test.dart';
import 'package:foodsavr/firebase_options.dart';
import 'package:foodsavr/firebase_options_prod.dart';
import 'package:foodsavr/main.dart';

void main() {
  test('local runs target the test environment', () {
    expect(deployEnvironment, 'test');
  });

  test('non-production environments use the default options', () {
    if (DefaultFirebaseOptions.configured) {
      expect(
        firebaseOptionsFor('staging'),
        DefaultFirebaseOptions.currentPlatform,
      );
    } else {
      expect(() => firebaseOptionsFor('staging'), throwsStateError);
    }
  });

  test('unconfigured builds fail instead of using a baked-in project', () {
    if (!DefaultFirebaseOptions.configured) {
      expect(() => DefaultFirebaseOptions.currentPlatform, throwsStateError);
    }
  });

  test('production never falls back to the default options', () {
    if (ProdFirebaseOptions.configured) {
      expect(
        firebaseOptionsFor('production').projectId,
        isNot(DefaultFirebaseOptions.web.projectId),
      );
    } else {
      expect(() => firebaseOptionsFor('production'), throwsStateError);
    }
  });
}
