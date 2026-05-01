// ignore_for_file: avoid_print

import 'dart:io';
import 'package:foodsavr/services/standalone_seeding_service.dart';
import 'package:foodsavr/mock_data/collections.dart';
import 'package:foodsavr/mock_data/global_products.dart';
import 'package:foodsavr/mock_data/inventory_products.dart';
import 'package:foodsavr/models/product_model.dart';
import 'package:foodsavr/models/collection_model.dart';
import 'package:foodsavr/utils/collection_types.dart';

const String defaultProjectId = 'demo-project';
const String defaultHost = 'localhost';
const String defaultAuthPort = '9099';
const String defaultFirestorePort = '8080';

const String testUserEmail = 'bob@example.com';
const String testUserPassword = 'password123';

Future<void> main() async {
  print('Starting database seeding...');

  const env = String.fromEnvironment('ENV', defaultValue: 'local');
  final isRemote = env.startsWith('remote');

  final projectId = String.fromEnvironment(
    'FIREBASE_PROJECT_ID',
    defaultValue: defaultProjectId,
  );
  final apiKey = String.fromEnvironment(
    'FIREBASE_API_KEY',
    defaultValue: 'fake-key',
  );

  if (isRemote) {
    print('Environment: Remote ($env)');
    print('   Project ID: $projectId');
  } else {
    print('Environment: Local Emulator');
  }

  final seedingService = StandaloneSeedingService(
    projectId: projectId,
    host: defaultHost,
    authPort: defaultAuthPort,
    firestorePort: defaultFirestorePort,
    apiKey: apiKey,
    isRemote: isRemote,
  );

  if (!await seedingService.checkEmulators()) {
    print('Error: Firebase Emulators are not running.');
    print('   Please run "make start-firebase-emulators" first.');
    exit(1);
  }

  try {
    print('Creating/Signing in test user: $testUserEmail...');
    final userId = await seedingService.createTestUser(
      testUserEmail,
      testUserPassword,
    );
    print('User ID: $userId');

    final allRecords = <SeedRecord>[];
    final now = DateTime.now();

    // 1. Map Inventory Products
    print('Preparing inventory products...');
    final inventoryData = InventoryProductsData.getProducts();
    for (var data in inventoryData) {
      final id = data['id'] as int;
      final expirationDays = data['expirationDays'] as int?;
      final quantity = data['quantity'] as int? ?? 1;

      final product = Product(
        id: id,
        name: data['name'] as String,
        description: data['description'] as String,
        userId: userId,
        nonExpiringQuantity: expirationDays == null ? quantity : 0,
        expiries: expirationDays != null
            ? [
                ExpiryEntry(
                  quantity: quantity,
                  expirationDate: now.add(Duration(days: expirationDays)),
                ),
              ]
            : [],
        category: data['category'] as String?,
      );
      allRecords.add(
        SeedRecord('products', id.toString(), product.toFirestoreRest()),
      );
    }

    // 2. Map Global Products
    print('Preparing global products...');
    final globalData = GlobalProductsData.getProducts();
    for (var data in globalData) {
      final id = data['id'] as int;
      final product = Product(
        id: id,
        name: data['name'] as String,
        description: data['description'] as String,
        userId: 'global',
        isGlobal: true,
        category: data['category'] as String?,
        registryType: 'global',
      );
      allRecords.add(
        SeedRecord('products', id.toString(), product.toFirestoreRest()),
      );
    }

    // 3. Map Collections
    print('Preparing collections...');
    final collectionsData = CollectionsData.getCollections();
    for (var data in collectionsData) {
      final id = data['id'] as String;
      final mockProductIds = List<int>.from(data['productIds'] as List);

      final collection = Collection(
        id: id,
        name: data['name'] as String,
        productIds: mockProductIds,
        userId: userId,
        description: data['description'] as String?,
        type: CollectionType.values.firstWhere(
          (e) => e.name == data['type'],
          orElse: () => CollectionType.inventory,
        ),
      );
      allRecords.add(
        SeedRecord('collections', id, collection.toFirestoreRest()),
      );
    }

    print('Seeding ${allRecords.length} total records in batches...');
    await seedingService.seedBatch(allRecords);

    print('\nDatabase seeding completed successfully!');
  } catch (e) {
    print('Error during seeding: $e');
    exit(1);
  }
}
