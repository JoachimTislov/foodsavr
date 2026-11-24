import 'package:flutter_test/flutter_test.dart';
import 'package:foodsavr/firebase_options.dart';
import 'package:foodsavr/firebase_options_prod.dart';
import 'package:foodsavr/main.dart';

void main() {
  test('local runs target the test project', () {
    expect(deployEnvironment, 'test');
    expect(
      firebaseOptionsFor(deployEnvironment),
      DefaultFirebaseOptions.currentPlatform,
    );
  });

  test('non-production environments use the tracked test options', () {
    expect(
      firebaseOptionsFor('staging'),
      DefaultFirebaseOptions.currentPlatform,
    );
  });

  test('production never falls back to the test options', () {
    if (ProdFirebaseOptions.configured) {
      expect(
        firebaseOptionsFor('production').projectId,
        isNot(DefaultFirebaseOptions.currentPlatform.projectId),
      );
    } else {
      expect(() => firebaseOptionsFor('production'), throwsStateError);
    }
  });
}
