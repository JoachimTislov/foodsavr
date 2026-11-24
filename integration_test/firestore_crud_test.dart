import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foodsavr/models/collection_model.dart';
import 'package:foodsavr/models/product_model.dart';
import 'package:foodsavr/repositories/collection_repository.dart';
import 'package:foodsavr/repositories/product_repository.dart';
import 'package:foodsavr/utils/collection_types.dart';
import 'package:integration_test/integration_test.dart';

import 'test_harness.dart';

export 'test_harness.dart' show emulatorTestOptions;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  registerFirestoreCrudTests();
}

void registerFirestoreCrudTests() {
  group('firestore CRUD integration', () {
    late String productId;
    late String collectionId;
    late FirebaseFirestore firestore;
    late ProductRepository repository;
    late CollectionRepository collectionRepository;

    setUpAll(() async {
      await ensureEmulatorInitialized();
      final runId = DateTime.now().millisecondsSinceEpoch;
      productId = 'it-crud-1-$runId';
      collectionId = 'it-col-1-$runId';
      firestore = FirebaseFirestore.instance;
      repository = ProductRepository(firestore);
      collectionRepository = CollectionRepository(firestore);
    });

    tearDown(() async {
      await firestore.collection('products').doc(productId).delete();
      await firestore.collection('collections').doc(collectionId).delete();
    });

    testWidgets('Product CRUD round-trip', (tester) async {
      final expiry = DateTime.now().add(const Duration(days: 5));
      final product = Product(
        id: productId,
        name: 'Integration Test Milk',
        description: 'Created by firestore_crud_test',
        userId: 'it-user',
        expiries: [ExpiryEntry(quantity: 2, expirationDate: expiry)],
        category: 'dairy',
        registryType: 'personal',
      );

      await repository.add(product);
      final fetched = await repository.get(productId);
      expect(fetched, isNotNull);
      expect(fetched!.name, 'Integration Test Milk');
      expect(fetched.quantity, 2);
      expect(fetched.expiries.single.expirationDate.year, expiry.year);

      final updated = fetched.copyWith(name: 'Integration Test Milk V2');
      await repository.update(updated);
      final refetched = await repository.get(productId);
      expect(refetched!.name, 'Integration Test Milk V2');

      final personal = await repository.getPersonalProducts('it-user');
      expect(personal.any((p) => p.id == productId), isTrue);

      await repository.delete(productId);
      expect(await repository.get(productId), isNull);
    });

    testWidgets('Collection CRUD round-trip', (tester) async {
      final collection = Collection(
        id: collectionId,
        name: 'Integration Test Collection',
        productIds: const [],
        userId: 'it-user',
        type: CollectionType.inventory,
      );

      await collectionRepository.add(collection);
      final fetched = await collectionRepository.get(collectionId);
      expect(fetched, isNotNull);
      expect(fetched!.name, 'Integration Test Collection');

      final updated = fetched.copyWith(name: 'Test Collection V2');
      await collectionRepository.update(updated);
      final refetched = await collectionRepository.get(collectionId);
      expect(refetched!.name, 'Test Collection V2');

      await collectionRepository.delete(collectionId);
      expect(await collectionRepository.get(collectionId), isNull);
    });
  });
}
