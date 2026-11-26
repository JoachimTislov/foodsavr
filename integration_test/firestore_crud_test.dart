import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
    late String owner;
    late String productId;
    late String collectionId;
    late FirebaseFirestore firestore;
    late ProductRepository repository;
    late CollectionRepository collectionRepository;

    setUpAll(() async {
      await signInEmulatorOwner();
      owner = FirebaseAuth.instance.currentUser!.uid;
      final runId = DateTime.now().millisecondsSinceEpoch;
      productId = 'it-crud-1-$runId';
      collectionId = 'it-col-1-$runId';
      firestore = FirebaseFirestore.instance;
      repository = ProductRepository(firestore);
      collectionRepository = CollectionRepository(firestore);
    });

    tearDown(() async {
      await deleteEmulatorFixture('products/$productId');
      await deleteEmulatorFixture('collections/$collectionId');
    });

    testWidgets('Product CRUD round-trip', (tester) async {
      final expiry = DateTime.now().add(const Duration(days: 5));
      final product = Product(
        id: productId,
        name: 'Integration Test Milk',
        description: 'Created by firestore_crud_test',
        userId: owner,
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

      final personal = await repository.getPersonalProducts(owner);
      expect(personal.any((p) => p.id == productId), isTrue);

      await repository.delete(productId);
      expect(await emulatorDocumentExists('products/$productId'), isFalse);
    });

    testWidgets('Collection CRUD round-trip', (tester) async {
      final collection = Collection(
        id: collectionId,
        name: 'Integration Test Collection',
        productIds: const [],
        userId: owner,
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
      expect(
        await emulatorDocumentExists('collections/$collectionId'),
        isFalse,
      );
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
    late CollectionRepository foreignCollections;
    late FirebaseFirestore foreignFirestore;
    late FirebaseFirestore remote;
    const missingId = 'legacy-missing';

    setUpAll(() async {
      final credentials = await signInEmulatorOwner();
      remote = await signedInEmulatorClient(
        'deletion-remote',
        credentials: credentials,
      );
      foreignFirestore = await signedInEmulatorClient('deletion-foreign');
      foreignCollections = CollectionRepository(foreignFirestore);
    });

    tearDownAll(() async {
      for (final client in [remote, foreignFirestore]) {
        await client.terminate();
        await client.app.delete();
      }
    });

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
      owner = FirebaseAuth.instance.currentUser!.uid;
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
      foreign = Collection(
        id: 'foreign-$owner',
        name: 'Other owner',
        productIds: [member.id],
        userId: FirebaseAuth.instanceFor(
          app: foreignFirestore.app,
        ).currentUser!.uid,
      );
      // The foreign owner seeds a legacy reference outside client validation.
      await foreignFirestore
          .collection('collections')
          .doc(foreign.id)
          .set(foreign.toJson());
      fresh = await collections.add(
        Collection(id: '', name: 'Fresh', productIds: const [], userId: owner),
      );
    });

    tearDown(() async {
      await Future.wait([
        for (final product in [member, kept])
          deleteEmulatorFixture('products/${product.id}'),
        for (final collection in [source, target, shoppingList, foreign, fresh])
          deleteEmulatorFixture('collections/${collection.id}'),
      ]);
      collections.afterMembershipRead = null;
      collections.beforeMembershipCommit = null;
      collections.beforeDanglingPrune = null;
      productRepository.afterDiscovery = null;
    });

    // On web, transactions reach the backend even with the network disabled.
    // Stalling the verifying transaction past its deadline forces the queued
    // fallback, as a slow or unreachable server does.
    void stallMembershipTransactions() {
      final stall = Completer<void>();
      collections.afterMembershipRead = () => stall.future;
      addTearDown(stall.complete);
    }

    testWidgets('offline membership adds return promptly and sync', (
      tester,
    ) async {
      final draft = fresh.copyWith(
        id: 'offline-draft-$owner',
        productIds: [member.id],
      );
      addTearDown(() => deleteEmulatorFixture('collections/${draft.id}'));
      final collectionRef = firestore.collection('collections').doc(fresh.id);
      await collectionRef.get();
      stallMembershipTransactions();
      await firestore.disableNetwork();
      try {
        await collections
            .addProduct(fresh.id, member.id)
            .timeout(const Duration(seconds: 5));
        final pending = await collectionRef.get(
          const GetOptions(source: Source.cache),
        );
        expect(pending.metadata.hasPendingWrites, isTrue);
        expect(pending.data()!['productIds'], [member.id]);

        await collections
            .addProducts(fresh.id, [kept.id, member.id])
            .timeout(const Duration(seconds: 5));
        await collections.add(draft).timeout(const Duration(seconds: 5));
        expect((await collections.get(draft.id))!.productIds, [member.id]);
        expect(
          (await CollectionRepository(remote).get(fresh.id))!.productIds,
          isEmpty,
        );
        expect(
          await emulatorDocumentExists('collections/${draft.id}'),
          isFalse,
        );
      } finally {
        await firestore.enableNetwork();
      }
      await firestore.waitForPendingWrites();
      final remoteCollections = CollectionRepository(remote);
      expect((await remoteCollections.get(fresh.id))!.productIds, [
        member.id,
        kept.id,
      ]);
      expect((await remoteCollections.get(draft.id))!.productIds, [member.id]);
    });

    testWidgets('server read hides and prunes an offline add racing a delete', (
      tester,
    ) async {
      await collections.get(fresh.id);
      stallMembershipTransactions();
      await firestore.disableNetwork();
      try {
        await collections
            .addProduct(fresh.id, kept.id)
            .timeout(const Duration(seconds: 5));
        // Another device deletes the product before the queued add syncs.
        await remote.collection('products').doc(kept.id).delete();
      } finally {
        await firestore.enableNetwork();
      }
      await firestore.waitForPendingWrites();
      // The rules accept the queued add although the product is gone.
      final saved = (await CollectionRepository(remote).get(fresh.id))!;
      expect(saved.productIds, [kept.id]);

      final (loaded, visible) = await collectionService.loadContents(saved);
      expect(loaded.productIds, isEmpty);
      expect(visible, isEmpty);
      expect(await collectionService.resolveCounts(owner, [saved]), {
        fresh.id: 0,
      });
      await _expectEventually(
        () async =>
            (await CollectionRepository(remote).get(fresh.id))!.productIds,
        isEmpty,
      );
    });

    for (final create in [true, false]) {
      testWidgets(
        create
            ? 'a timed-out create never overwrites later edits'
            : 'a timed-out add never overwrites later edits',
        (tester) async {
          final draft = fresh.copyWith(
            id: 'timed-out-$owner',
            productIds: [member.id],
          );
          addTearDown(() => deleteEmulatorFixture('collections/${draft.id}'));
          final target = create ? draft : fresh;
          final stall = Completer<void>();
          addTearDown(() => stall.isCompleted ? null : stall.complete());
          collections.afterMembershipRead = () => stall.future;
          if (create) {
            await collections.add(draft).timeout(const Duration(seconds: 5));
          } else {
            await collections
                .addProduct(fresh.id, member.id)
                .timeout(const Duration(seconds: 5));
          }
          await firestore.waitForPendingWrites();
          // The user edits the collection after the add reported success.
          await collections.update(
            target.copyWith(name: 'Edited'),
            metadataOnly: true,
          );
          await collections.removeProduct(target.id, member.id);
          await firestore.waitForPendingWrites();

          stall.complete();
          await Future<void>.delayed(const Duration(seconds: 2));
          final saved = (await CollectionRepository(remote).get(target.id))!;
          expect(saved.name, 'Edited');
          expect(saved.productIds, isEmpty);
        },
      );
    }

    for (final create in [true, false]) {
      testWidgets(
        create
            ? 'a create commit delayed past the deadline is awaited'
            : 'an add commit delayed past the deadline is awaited',
        (tester) async {
          final draft = fresh.copyWith(
            id: 'delayed-commit-$owner',
            productIds: [member.id],
          );
          addTearDown(() => deleteEmulatorFixture('collections/${draft.id}'));
          final target = create ? draft : fresh;
          final release = Completer<void>();
          addTearDown(() => release.isCompleted ? null : release.complete());
          collections.beforeMembershipCommit = () => release.future;
          var done = false;
          final adding =
              (create
                      ? collections.add(draft)
                      : collections.addProduct(fresh.id, member.id))
                  .then((_) => done = true);

          // No fallback write may race the staged commit.
          await Future<void>.delayed(const Duration(seconds: 3));
          expect(done, isFalse);
          expect(
            await emulatorDocumentExists('collections/${draft.id}'),
            isFalse,
          );
          expect(
            (await CollectionRepository(remote).get(fresh.id))!.productIds,
            isEmpty,
          );

          release.complete();
          await adding.timeout(const Duration(seconds: 10));
          await collections.update(
            target.copyWith(name: 'Edited'),
            metadataOnly: true,
          );
          final saved = (await CollectionRepository(remote).get(target.id))!;
          expect(saved.name, 'Edited');
          expect(saved.productIds, [member.id]);
        },
      );
    }

    testWidgets('a product re-added during repair keeps its membership', (
      tester,
    ) async {
      await collections.addProduct(fresh.id, kept.id);
      await remote.collection('products').doc(kept.id).delete();
      final saved = (await CollectionRepository(remote).get(fresh.id))!;
      final reached = Completer<void>();
      final held = Completer<void>();
      addTearDown(() => held.isCompleted ? null : held.complete());
      collections.beforeDanglingPrune = () {
        reached.complete();
        return held.future;
      };

      final (_, visible) = await collectionService.loadContents(saved);
      expect(visible, isEmpty);
      // The server confirmed the product missing; the prune is now held.
      await reached.future.timeout(const Duration(seconds: 10));
      await remote.collection('products').doc(kept.id).set(kept.toJson());
      await CollectionRepository(remote).addProduct(fresh.id, kept.id);
      held.complete();
      await Future<void>.delayed(const Duration(seconds: 2));

      expect((await CollectionRepository(remote).get(fresh.id))!.productIds, [
        kept.id,
      ]);
      final (_, restored) = await collectionService.loadContents(saved);
      expect(restored.map((product) => product.id), [kept.id]);
    });

    testWidgets('a rejected queued add is rolled back and never replayed', (
      tester,
    ) async {
      final collectionRef = firestore.collection('collections').doc(fresh.id);
      await collectionRef.get();
      stallMembershipTransactions();
      await firestore.disableNetwork();
      try {
        await collections
            .addProducts(fresh.id, [kept.id])
            .timeout(const Duration(seconds: 5));
        expect(
          (await collectionRef.get(
            const GetOptions(source: Source.cache),
          )).data()!['productIds'],
          [kept.id],
        );
        // Another device deletes the collection, so the server rejects the add.
        await CollectionRepository(remote).delete(fresh.id);
      } finally {
        await firestore.enableNetwork();
      }
      await firestore.waitForPendingWrites();
      expect(await emulatorDocumentExists('collections/${fresh.id}'), isFalse);
      final local = await collectionRef.get(
        const GetOptions(source: Source.cache),
      );
      expect(local.metadata.hasPendingWrites, isFalse);
      expect(local.data()?['productIds'] ?? const [], isNot(contains(kept.id)));
      final listed = await collectionService.getCollectionsForUser(owner);
      expect(
        listed.map((collection) => collection.id),
        isNot(contains(fresh.id)),
      );
      expect(await emulatorDocumentExists('collections/${fresh.id}'), isFalse);
    });

    testWidgets('offline collection loads tolerate an incomplete cache', (
      tester,
    ) async {
      await collections.getMemberProducts(owner);
      final uncached = await ProductRepository(
        remote,
      ).add(Product(id: '', name: 'Tea', description: '', userId: owner));
      addTearDown(
        () => remote.collection('products').doc(uncached.id).delete(),
      );
      await CollectionRepository(remote).addProduct(source.id, uncached.id);
      final listedOnline = await collectionService.getCollectionsForUser(owner);
      final cached = listedOnline.singleWhere((item) => item.id == source.id);
      expect(cached.productIds, [member.id, missingId, uncached.id]);

      await firestore.disableNetwork();
      try {
        final listed = await collectionService.getCollectionsForUser(owner);
        expect(listed, contains(cached));
        expect(await collectionService.resolveCounts(owner, [cached]), {
          source.id: 1,
        });
        final (loaded, visible) = await collectionService.loadContents(cached);
        expect(loaded.productIds, [member.id]);
        expect(visible.map((p) => p.id), [member.id]);
        expect(
          (await collections.get(source.id))!.productIds,
          cached.productIds,
        );
      } finally {
        await firestore.enableNetwork();
      }
      await firestore.waitForPendingWrites();
      expect((await collections.get(source.id))!.productIds, cached.productIds);
      final (_, visible) = await collectionService.loadContents(cached);
      expect(visible.map((p) => p.id), [member.id, uncached.id]);
      await _expectEventually(
        () async => (await collections.get(source.id))!.productIds,
        [member.id, uncached.id],
      );
    });

    for (final removeDiscoveredCollection in [false, true]) {
      testWidgets(
        removeDiscoveredCollection
            ? 'queued delete recovers when a discovered collection disappears'
            : 'single delete queues one atomic offline write before acknowledgement',
        (tester) async {
          expect(await products.getProducts(owner), hasLength(2));
          await collectionService.getCollectionsForUser(owner);
          await firestore.disableNetwork();
          final collectionRef = firestore
              .collection('collections')
              .doc(target.id);
          final productRef = firestore.collection('products').doc(member.id);
          var acknowledged = false;
          late Future<void> deletion;
          try {
            final localRemoval = collectionRef
                .snapshots(includeMetadataChanges: true)
                .firstWhere(
                  (snapshot) =>
                      snapshot.metadata.hasPendingWrites &&
                      !(snapshot.data()!['productIds'] as List).contains(
                        member.id,
                      ),
                );
            deletion = products.deleteProduct(member.id).then((_) {
              acknowledged = true;
            });
            await Future.any([
              localRemoval.then<void>((_) {}),
              deletion,
            ]).timeout(const Duration(seconds: 10));
            expect(acknowledged, isFalse);
            expect(
              (await productRef.get(
                const GetOptions(source: Source.cache),
              )).exists,
              isFalse,
            );
            expect(await ProductRepository(remote).get(member.id), isNotNull);
            expect(
              (await CollectionRepository(remote).get(target.id))!.productIds,
              [kept.id, member.id],
            );
            if (removeDiscoveredCollection) {
              await CollectionRepository(remote).delete(fresh.id);
            }
          } finally {
            await firestore.enableNetwork();
          }
          await deletion;
          expect(
            await emulatorDocumentExists('products/${member.id}'),
            isFalse,
          );
          expect(
            (await CollectionRepository(remote).get(target.id))!.productIds,
            [kept.id],
          );
          expect((await products.getProducts(owner)).map((p) => p.id), [
            kept.id,
          ]);
          expect((await collections.get(shoppingList.id))!.productIds, isEmpty);
          if (removeDiscoveredCollection) {
            expect(
              await emulatorDocumentExists('collections/${fresh.id}'),
              isFalse,
            );
          }
        },
      );
    }

    testWidgets(
      'metadata edits preserve concurrent membership adds and removals',
      (tester) async {
        final opening = (await collections.get(fresh.id))!;
        await collections.addProduct(fresh.id, member.id);
        await collectionService.updateCollection(
          opening.copyWith(name: 'After add'),
          metadataOnly: true,
        );
        final renamed = (await collections.get(fresh.id))!;
        expect(renamed.name, 'After add');
        expect(renamed.productIds, [member.id]);

        await collections.removeProduct(fresh.id, member.id);
        await firestore.collection('products').doc(member.id).delete();
        await collectionService.updateCollection(
          renamed.copyWith(name: 'After removal'),
          metadataOnly: true,
        );
        final renamedAgain = (await collections.get(fresh.id))!;
        expect(renamedAgain.name, 'After removal');
        expect(renamedAgain.productIds, isEmpty);
      },
    );

    testWidgets('product delete prunes all owner memberships', (tester) async {
      await products.deleteProduct(member.id);

      expect(await emulatorDocumentExists('products/${member.id}'), isFalse);
      expect((await collections.get(source.id))!.productIds, [missingId]);
      expect((await collections.get(target.id))!.productIds, [kept.id]);
      expect((await collections.get(shoppingList.id))!.productIds, isEmpty);
      expect((await foreignCollections.get(foreign.id))!.productIds, [
        member.id,
      ]);
    });

    testWidgets('move keeps the products and removes the source', (
      tester,
    ) async {
      await collections.removeProduct(target.id, member.id);
      await products.deleteCollection(source, destinationId: target.id);

      expect(await emulatorDocumentExists('collections/${source.id}'), isFalse);
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
      await foreignCollections.removeProduct(foreign.id, member.id);
      await collections.removeProduct(shoppingList.id, member.id);
      final foreignBefore = await foreignCollections.get(foreign.id);
      final shoppingBefore = await collections.get(shoppingList.id);
      final missingDestination = 'removed-$owner';

      for (final id in [foreign.id, shoppingList.id, missingDestination]) {
        await expectLater(
          products.deleteCollection(source, destinationId: id),
          throwsA(anything),
        );
        expect(await collections.get(source.id), source);
      }
      expect(await products.getProductById(member.id), isNotNull);
      expect(await foreignCollections.get(foreign.id), foreignBefore);
      expect(await collections.get(shoppingList.id), shoppingBefore);
      expect(
        await emulatorDocumentExists('collections/$missingDestination'),
        isFalse,
      );
    });

    testWidgets(
      'shopping list deletion preserves products and inventory membership',
      (tester) async {
        await products.deleteCollection(shoppingList);

        expect(
          await emulatorDocumentExists('collections/${shoppingList.id}'),
          isFalse,
        );
        expect(await products.getProductById(member.id), isNotNull);
        expect(await collections.get(target.id), target);
        expect(await collections.get(source.id), source);
      },
    );

    testWidgets('inventory-only deletion preserves its products', (
      tester,
    ) async {
      await collections.addProduct(source.id, kept.id);
      await collections.removeProduct(target.id, kept.id);
      await collectionService.deleteCollectionOnly(source.id);

      expect(await emulatorDocumentExists('collections/${source.id}'), isFalse);
      expect(await products.getProductById(kept.id), isNotNull);
      expect(await products.getProductById(member.id), isNotNull);
    });

    testWidgets('inventory delete with items deletes only unshared products', (
      tester,
    ) async {
      await collections.addProduct(source.id, kept.id);
      await collections.removeProduct(target.id, kept.id);
      final inventoryBefore = await collections.get(target.id);

      await products.deleteCollection((await collections.get(source.id))!);

      expect(await emulatorDocumentExists('collections/${source.id}'), isFalse);
      expect(await emulatorDocumentExists('products/${kept.id}'), isFalse);
      expect(await products.getProductById(member.id), isNotNull);
      expect(await collections.get(target.id), inventoryBefore);
      expect(await collections.get(shoppingList.id), shoppingList);
      expect(await foreignCollections.get(foreign.id), foreign);
    });

    testWidgets('product delete removes a membership added after discovery', (
      tester,
    ) async {
      productRepository.afterDiscovery = () =>
          collections.addProduct(fresh.id, member.id);

      await products.deleteProduct(member.id);

      expect(await emulatorDocumentExists('products/${member.id}'), isFalse);
      expect((await collections.get(fresh.id))!.productIds, isEmpty);
      expect((await foreignCollections.get(foreign.id))!.productIds, [
        member.id,
      ]);
    });

    testWidgets(
      'inventory delete keeps a product added to another collection after discovery',
      (tester) async {
        await collections.removeProduct(target.id, member.id);
        await collections.removeProduct(shoppingList.id, member.id);
        productRepository.afterDiscovery = () =>
            collections.addProduct(fresh.id, member.id);

        await products.deleteCollection(source);

        expect(await products.getProductById(member.id), isNotNull);
        expect((await collections.get(fresh.id))!.productIds, [member.id]);
      },
    );

    testWidgets('inventory delete skips a sibling deleted after discovery', (
      tester,
    ) async {
      await collections.removeProduct(target.id, member.id);
      await collections.removeProduct(shoppingList.id, member.id);
      await collections.addProduct(fresh.id, member.id);
      productRepository.afterDiscovery = () => collections.delete(fresh.id);

      await products.deleteCollection(source);

      expect(await emulatorDocumentExists('collections/${source.id}'), isFalse);
      expect(await emulatorDocumentExists('collections/${fresh.id}'), isFalse);
      expect(await emulatorDocumentExists('products/${member.id}'), isFalse);
    });

    testWidgets('a collection created after discovery is repaired on read', (
      tester,
    ) async {
      late Collection added;
      productRepository.afterDiscovery = () async {
        added = await collections.add(
          fresh.copyWith(id: '', productIds: [member.id, kept.id]),
        );
        addTearDown(() => collections.delete(added.id));
      };

      await products.deleteProduct(member.id);

      expect((await collections.get(added.id))!.productIds, [
        member.id,
        kept.id,
      ]);
      final (loaded, visible) = await collectionService.loadContents(added);
      expect(visible.map((product) => product.id), [kept.id]);
      expect(loaded.productIds, [kept.id]);
      await _expectEventually(
        () async => (await collections.get(added.id))!.productIds,
        [kept.id],
      );
    });

    testWidgets('bulk deletion tolerates a product deleted after discovery', (
      tester,
    ) async {
      await collections.removeProduct(target.id, member.id);
      await collections.removeProduct(shoppingList.id, member.id);
      productRepository.afterDiscovery = () =>
          firestore.collection('products').doc(member.id).delete();

      await products.deleteCollection(source);

      expect(await emulatorDocumentExists('collections/${source.id}'), isFalse);
      expect((await collections.get(target.id))!.productIds, [kept.id]);
    });

    testWidgets('a collection deleted after discovery does not fail deletes', (
      tester,
    ) async {
      productRepository.afterDiscovery = () => collections.delete(fresh.id);

      await products.deleteProduct(member.id);

      expect(await emulatorDocumentExists('products/${member.id}'), isFalse);
      expect(await emulatorDocumentExists('collections/${fresh.id}'), isFalse);
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
        _throwsUnavailableProduct(kept.id),
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
        _throwsUnavailableProduct(kept.id),
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
      expect(await emulatorDocumentExists('collections/${draft.id}'), isFalse);

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

      collections.afterMembershipRead = () =>
          firestore.collection('products').doc(member.id).delete();
      await expectLater(
        collections.add(draft.copyWith(productIds: [member.id])),
        _throwsUnavailableProduct(member.id),
      );
      expect(await emulatorDocumentExists('collections/${draft.id}'), isFalse);

      collections.afterMembershipRead = () =>
          firestore.collection('products').doc(kept.id).delete();
      final savedTarget = (await collections.get(source.id))!;
      await expectLater(
        collections.update(
          savedTarget.copyWith(
            productIds: [...savedTarget.productIds, kept.id],
          ),
        ),
        throwsStateError,
      );
      expect(await collections.get(source.id), savedTarget);
    });

    testWidgets('denied collection write preserves permission-denied', (
      tester,
    ) async {
      final invalid = fresh.copyWith(
        id: 'invalid-name-$owner',
        name: 'a' * 201,
        productIds: [member.id],
      );

      await expectLater(
        collections.add(invalid),
        throwsA(
          isA<FirebaseException>().having(
            (error) => error.code,
            'code',
            'permission-denied',
          ),
        ),
      );
      expect(
        await emulatorDocumentExists('collections/${invalid.id}'),
        isFalse,
      );
      expect(await products.getProductById(member.id), isNotNull);
    });

    testWidgets(
      'populated collection batch rejects missing products atomically',
      (tester) async {
        final valid = fresh.copyWith(
          id: 'new-valid-$owner',
          productIds: [kept.id],
        );
        final invalid = fresh.copyWith(
          id: 'new-invalid-$owner',
          productIds: ['never-existed'],
        );
        await expectLater(
          collections.addCollectionsInBatch([valid, invalid]),
          throwsStateError,
        );
        expect(
          await emulatorDocumentExists('collections/${valid.id}'),
          isFalse,
        );
        expect(
          await emulatorDocumentExists('collections/${invalid.id}'),
          isFalse,
        );
      },
    );

    testWidgets(
      'legacy dangling membership is excluded from counts and repaired',
      (tester) async {
        expect(await collectionService.resolveCounts(owner, [source]), {
          source.id: 1,
        });
        final (cleaned, visible) = await collectionService.loadContents(source);

        expect(visible.map((p) => p.id), [member.id]);
        expect(cleaned.productIds, [member.id]);
        await _expectEventually(
          () async => (await collections.get(source.id))!.productIds,
          [member.id],
        );
      },
    );
  });
}

Matcher _throwsUnavailableProduct(String id) => throwsA(
  isA<StateError>().having(
    (error) => error.message,
    'message',
    'Product $id is unavailable. Reload and try again.',
  ),
);

/// Read repair runs in the background, so poll for its result.
Future<void> _expectEventually(
  Future<Object?> Function() read,
  Object? matcher,
) async {
  for (var attempt = 0; attempt < 25; attempt++) {
    if (wrapMatcher(matcher).matches(await read(), {})) return;
    await Future<void>.delayed(const Duration(milliseconds: 200));
  }
  expect(await read(), matcher);
}
