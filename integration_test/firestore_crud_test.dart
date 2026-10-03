import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foodsavr/models/collection_model.dart';
import 'package:foodsavr/models/product_model.dart';
import 'package:foodsavr/repositories/collection_repository.dart';
import 'package:foodsavr/repositories/product_repository.dart';
import 'package:foodsavr/utils/collection_types.dart';
import 'package:integration_test/integration_test.dart';

const emulatorTestOptions = FirebaseOptions(
  apiKey: 'AIzaSyDummyKeyForDemoOnly',
  appId: '1:1234567890:android:dummyid123456',
  messagingSenderId: '',
  projectId: 'demo-project',
);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await Firebase.initializeApp(options: emulatorTestOptions);
    FirebaseFirestore.instance.useFirestoreEmulator('localhost', 8080);
  });

  final firestore = FirebaseFirestore.instance;
  final repository = ProductRepository(firestore);
  final collectionRepository = CollectionRepository(firestore);

  testWidgets('Product CRUD round-trip against Firestore emulator', (
    tester,
  ) async {
    final expiry = DateTime.now().add(const Duration(days: 5));
    final product = Product(
      id: 'it-crud-1',
      name: 'Integration Test Milk',
      description: 'Created by firestore_crud_test',
      userId: 'it-user',
      expiries: [ExpiryEntry(quantity: 2, expirationDate: expiry)],
      category: 'dairy',
      registryType: 'personal',
    );

    await repository.add(product);
    final fetched = await repository.get('it-crud-1');
    expect(fetched, isNotNull);
    expect(fetched!.name, 'Integration Test Milk');
    expect(fetched.quantity, 2);
    expect(fetched.expiries.single.expirationDate.year, expiry.year);

    final updated = fetched.copyWith(
      name: 'Integration Test Milk Updated',
    );
    await repository.update(updated);
    final refetched = await repository.get('it-crud-1');
    expect(refetched!.name, 'Integration Test Milk Updated');

    final personal = await repository.getPersonalProducts('it-user');
    expect(personal.any((p) => p.id == 'it-crud-1'), isTrue);

    await repository.delete('it-crud-1');
    expect(await repository.get('it-crud-1'), isNull);
  });

  testWidgets('Collection CRUD round-trip against Firestore emulator', (
    tester,
  ) async {
    final collection = Collection(
      id: 'it-col-1',
      name: 'Integration Test Collection',
      productIds: const [],
      userId: 'it-user',
      type: CollectionType.inventory,
    );

    await collectionRepository.add(collection);
    final fetched = await collectionRepository.get('it-col-1');
    expect(fetched, isNotNull);
    expect(fetched!.name, 'Integration Test Collection');

    final updated = fetched.copyWith(
      name: 'Integration Test Collection Updated',
    );
    await collectionRepository.update(updated);
    final refetched = await collectionRepository.get('it-col-1');
    expect(refetched!.name, 'Integration Test Collection Updated');

    await collectionRepository.delete('it-col-1');
    expect(await collectionRepository.get('it-col-1'), isNull);
  });

  tearDown(() async {
    await firestore.collection('products').doc('it-crud-1').delete();
    await firestore.collection('collections').doc('it-col-1').delete();
  });
}
