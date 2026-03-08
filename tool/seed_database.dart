// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

// Mock data classes
import 'package:foodsavr/mock_data/collections.dart';
import 'package:foodsavr/mock_data/global_products.dart';
import 'package:foodsavr/mock_data/inventory_products.dart';
import 'package:foodsavr/models/product_model.dart';
import 'package:foodsavr/models/collection_model.dart';
import 'package:foodsavr/utils/collection_types.dart';

const String projectId = 'demo-project';
const String host = 'localhost';
const String authPort = '9099';
const String firestorePort = '8080';

const String testUserEmail = 'bob@example.com';
const String testUserPassword = 'password123';

Future<void> main() async {
  print('🚀 Starting database seeding...');

  if (!await checkEmulators()) {
    print('❌ Error: Firebase Emulators are not running.');
    print('   Please run "make start-firebase-emulators" first.');
    exit(1);
  }

  try {
    print('👤 Creating test user: $testUserEmail...');
    final userId = await createTestUser();
    print('✅ User created with ID: $userId');

    print('🍎 Seeding inventory products...');
    final addedProducts = await seedInventoryProducts(userId);
    print('✅ Seeded ${addedProducts.length} inventory products.');

    print('🌎 Seeding global products...');
    await seedGlobalProducts();
    print('✅ Seeded global products.');

    print('📦 Seeding collections...');
    await seedCollections(userId);
    print('✅ Seeded collections.');

    print('\n✨ Database seeding completed successfully!');
  } catch (e) {
    print('❌ Error during seeding: $e');
    exit(1);
  }
}

Future<bool> checkEmulators() async {
  try {
    final response = await http.get(Uri.parse('http://$host:$firestorePort/'));
    return response.statusCode == 200 || response.statusCode == 404;
  } catch (_) {
    return false;
  }
}

Future<String> createTestUser() async {
  final url =
      'http://$host:$authPort/identitytoolkit.googleapis.com/v1/accounts:signUp?key=fake-key';
  final response = await http.post(
    Uri.parse(url),
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({
      'email': testUserEmail,
      'password': testUserPassword,
      'returnSecureToken': true,
    }),
  );

  if (response.statusCode == 200) {
    final data = jsonDecode(response.body);
    return data['localId'];
  } else {
    final error = jsonDecode(response.body)['error'];
    if (error != null && error['message'] == 'EMAIL_EXISTS') {
      print('ℹ️  User already exists, signing in...');
      final signInUrl =
          'http://$host:$authPort/identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=fake-key';
      final signInResponse = await http.post(
        Uri.parse(signInUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': testUserEmail,
          'password': testUserPassword,
          'returnSecureToken': true,
        }),
      );

      if (signInResponse.statusCode == 200) {
        final data = jsonDecode(signInResponse.body);
        return data['localId'];
      }
    }
    throw Exception('Failed to create or sign in test user: ${response.body}');
  }
}

Future<List<int>> seedInventoryProducts(String userId) async {
  final productsData = InventoryProductsData.getProducts();
  final addedIds = <int>[];
  final now = DateTime.now();

  for (var data in productsData) {
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

    await postToFirestore('products', id.toString(), product.toFirestoreRest());
    addedIds.add(id);
  }
  return addedIds;
}

Future<void> seedGlobalProducts() async {
  final productsData = GlobalProductsData.getProducts();

  for (var data in productsData) {
    final id = data['id'] as int;
    final product = Product(
      id: id,
      name: data['name'] as String,
      description: data['description'] as String,
      userId: 'global',
      isGlobal: true,
      category: data['category'] as String?,
    );

    await postToFirestore('products', id.toString(), product.toFirestoreRest());
  }
}

Future<void> seedCollections(String userId) async {
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
      type: data['type'] == 'inventory'
          ? CollectionType.inventory
          : CollectionType.shoppingList,
    );

    await postToFirestore('collections', id, collection.toFirestoreRest());
  }
}

Future<void> postToFirestore(
  String collection,
  String documentId,
  Map<String, dynamic> fields,
) async {
  final url =
      'http://$host:$firestorePort/v1/projects/$projectId/databases/(default)/documents/$collection?documentId=$documentId';
  final response = await http.patch(
    Uri.parse(url),
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({'fields': fields}),
  );

  if (response.statusCode != 200) {
    throw Exception(
      'Failed to seed document $documentId in $collection: ${response.body}',
    );
  }
}
