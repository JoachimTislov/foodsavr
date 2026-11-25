import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foodsavr/models/collection_model.dart';
import 'package:foodsavr/models/product_model.dart';
import 'package:foodsavr/repositories/collection_repository.dart';
import 'package:foodsavr/repositories/product_repository.dart';
import 'package:foodsavr/utils/collection_types.dart';
import 'package:foodsavr/services/collection_service.dart';
import 'package:foodsavr/services/product_service.dart';
import 'package:foodsavr/utils/shelf_life.dart';
import 'package:foodsavr/validation/validators/collection_model_validator.dart';
import 'package:foodsavr/validation/validators/product_model_validator.dart';
import 'package:logger/logger.dart';
import 'package:integration_test/integration_test.dart';

import 'test_harness.dart';

export 'test_harness.dart' show emulatorTestOptions;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  registerFirestoreCrudTests();
}

void registerFirestoreCrudTests() {
  _registerDeletionTests();
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

void _registerDeletionTests() {
  group('collection deletion integrity', () {
    late FirebaseFirestore firestore;
    late CollectionRepository collections;
    late CollectionService collectionService;
    late ProductRepository productRepository;
    late ProductService products;
    late String owner;
    late Product member;
    late Product kept;
    late Collection source;
    late Collection target;
    late Collection shoppingList;
    late Collection foreign;
    late Collection fresh;
    const missingId = 'legacy-missing';

    setUp(() async {
      await ensureEmulatorInitialized();
      firestore = FirebaseFirestore.instance;
      productRepository = ProductRepository(firestore);
      collections = CollectionRepository(firestore);
      final logger = Logger(level: Level.off);
      collectionService = CollectionService(
        collections,
        CollectionModelValidator(),
        logger,
      );
      products = ProductService(
        productRepository,
        ProductModelValidator(),
        ShelfLifeService(),
        logger,
      );
      owner = 'it-owner-${DateTime.now().microsecondsSinceEpoch}';
      member = await products.addProduct(
        Product(id: '', name: 'Milk', description: '', userId: owner),
      );
      kept = await products.addProduct(
        Product(id: '', name: 'Oats', description: '', userId: owner),
      );
      source = await collections.add(
        Collection(
          id: '',
          name: 'Fridge',
          productIds: [member.id],
          userId: owner,
        ),
      );
      // A legacy writer left an ID without a product.
      await firestore.collection('collections').doc(source.id).update({
        'productIds': FieldValue.arrayUnion([missingId]),
      });
      source = source.copyWith(productIds: [member.id, missingId]);
      target = await collections.add(
        Collection(
          id: '',
          name: 'Pantry',
          productIds: [kept.id, member.id],
          userId: owner,
        ),
      );
      shoppingList = await collections.add(
        Collection(
          id: '',
          name: 'Shopping',
          productIds: [member.id],
          userId: owner,
          type: CollectionType.shoppingList,
        ),
      );
      foreign = await collections.add(
        Collection(
          id: '',
          name: 'Other owner',
          productIds: [member.id],
          userId: 'foreign-$owner',
        ),
      );
      fresh = await collections.add(
        Collection(id: '', name: 'Fresh', productIds: const [], userId: owner),
      );
    });

    tearDown(() async {
      await Future.wait([
        for (final product in [member, kept])
          firestore.collection('products').doc(product.id).delete(),
        for (final collection in [source, target, shoppingList, foreign, fresh])
          collections.delete(collection.id),
      ]);
      collections.afterMembershipRead = null;
      productRepository.afterDiscovery = null;
    });

    testWidgets('product delete prunes all owner memberships', (tester) async {
      await products.deleteProduct(member.id);

      expect(await products.getProductById(member.id), isNull);
      expect((await collections.get(source.id))!.productIds, [missingId]);
      expect((await collections.get(target.id))!.productIds, [kept.id]);
      expect((await collections.get(shoppingList.id))!.productIds, isEmpty);
      expect((await collections.get(foreign.id))!.productIds, [member.id]);
    });

    testWidgets('move keeps the products and removes the source', (
      tester,
    ) async {
      await collections.removeProduct(target.id, member.id);
      await products.deleteCollection(source, destinationId: target.id);

      expect(await collections.get(source.id), isNull);
      expect((await collections.get(target.id))!.productIds, [
        kept.id,
        member.id,
      ]);
      expect(await products.getProductById(member.id), isNotNull);
      expect((await collections.get(shoppingList.id))!.productIds, [member.id]);
    });

    testWidgets('invalid move destinations leave the source intact', (
      tester,
    ) async {
      for (final id in [foreign.id, shoppingList.id, 'removed-$owner']) {
        await expectLater(
          products.deleteCollection(source, destinationId: id),
          throwsA(anything),
        );
        expect(await collections.get(source.id), source);
      }
      expect(await products.getProductById(member.id), isNotNull);
    });

    testWidgets(
      'delete collection and products prunes other owner memberships',
      (tester) async {
        expect(await products.getProducts(owner), hasLength(2));
        await products.deleteCollection(source);

        expect(await collections.get(source.id), isNull);
        expect(await products.getProductById(member.id), isNull);
        expect((await products.getProducts(owner)).map((p) => p.id), [kept.id]);
        expect((await collections.get(target.id))!.productIds, [kept.id]);
        expect((await collections.get(shoppingList.id))!.productIds, isEmpty);
        expect((await collections.get(foreign.id))!.productIds, [member.id]);
      },
    );

    testWidgets('product delete removes a membership added after discovery', (
      tester,
    ) async {
      productRepository.afterDiscovery = () =>
          collections.addProduct(fresh.id, member.id);

      await products.deleteProduct(member.id);

      expect(await products.getProductById(member.id), isNull);
      expect((await collections.get(fresh.id))!.productIds, isEmpty);
      expect((await collections.get(foreign.id))!.productIds, [member.id]);
    });

    testWidgets(
      'collection and products delete removes a membership added after '
      'discovery',
      (tester) async {
        productRepository.afterDiscovery = () =>
            collections.addProduct(fresh.id, member.id);

        await products.deleteCollection(source);

        expect(await products.getProductById(member.id), isNull);
        expect((await collections.get(fresh.id))!.productIds, isEmpty);
        expect((await collections.get(target.id))!.productIds, [kept.id]);
      },
    );

    testWidgets('a collection deleted after discovery does not fail deletes', (
      tester,
    ) async {
      productRepository.afterDiscovery = () => collections.delete(fresh.id);

      await products.deleteProduct(member.id);

      expect(await products.getProductById(member.id), isNull);
      expect(await collections.get(fresh.id), isNull);
    });

    testWidgets('move fails and keeps the source when a product vanished', (
      tester,
    ) async {
      productRepository.afterDiscovery = () =>
          firestore.collection('products').doc(member.id).delete();

      await expectLater(
        products.deleteCollection(source, destinationId: fresh.id),
        throwsStateError,
      );

      expect(await collections.get(source.id), source);
      expect((await collections.get(fresh.id))!.productIds, isEmpty);
    });

    testWidgets('single add rejects a product deleted mid-transaction', (
      tester,
    ) async {
      collections.afterMembershipRead = () =>
          firestore.collection('products').doc(kept.id).delete();

      await expectLater(
        collections.addProduct(fresh.id, kept.id),
        throwsStateError,
      );

      expect((await collections.get(fresh.id))!.productIds, isEmpty);
    });

    testWidgets('bulk add writes nothing when one product is missing', (
      tester,
    ) async {
      await expectLater(
        collections.addProducts(fresh.id, [kept.id, 'never-existed']),
        throwsStateError,
      );
      collections.afterMembershipRead = () =>
          firestore.collection('products').doc(kept.id).delete();
      await expectLater(
        collections.addProducts(fresh.id, [kept.id, member.id]),
        throwsStateError,
      );

      expect((await collections.get(fresh.id))!.productIds, isEmpty);
    });

    testWidgets('populated create and update validate introduced products', (
      tester,
    ) async {
      final draft = Collection(
        id: 'it-draft-$owner',
        name: 'Draft',
        productIds: [kept.id, 'never-existed'],
        userId: owner,
      );
      await expectLater(collections.add(draft), throwsStateError);
      expect(await collections.get(draft.id), isNull);

      await expectLater(
        collections.update(fresh.copyWith(productIds: ['never-existed'])),
        throwsStateError,
      );
      expect((await collections.get(fresh.id))!.productIds, isEmpty);

      // Legacy IDs already present stay writable, so renames keep working.
      await collections.update(source.copyWith(name: 'Renamed'));
      expect((await collections.get(source.id))!.name, 'Renamed');

      await collections.update(fresh.copyWith(productIds: [kept.id]));
      expect((await collections.get(fresh.id))!.productIds, [kept.id]);
    });

    testWidgets(
      'legacy dangling membership is excluded from counts and repaired',
      (tester) async {
        expect(await collectionService.resolveCounts(owner, [source]), {
          source.id: 1,
        });
        final (cleaned, visible) = await collectionService.loadContents(source);

        expect(visible.map((p) => p.id), [member.id]);
        expect(cleaned.productIds, [member.id]);
        expect((await collections.get(source.id))!.productIds, [member.id]);
      },
    );
  });
}
