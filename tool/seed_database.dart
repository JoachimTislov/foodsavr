// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

// Mock data classes
import 'package:foodsavr/mock_data/collections.dart';
import 'package:foodsavr/mock_data/global_products.dart';
import 'package:foodsavr/mock_data/inventory_products.dart';

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
    await seedCollections(userId, addedProducts);
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
    // If user already exists, we might get an error. Let's try to sign in instead.
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

    final productMap = {
      'id': {'integerValue': id.toString()},
      'name': {'stringValue': data['name']},
      'description': {'stringValue': data['description']},
      'userId': {'stringValue': userId},
      'nonExpiringQuantity': {
        'integerValue': (expirationDays == null ? quantity : 0).toString(),
      },
      'isGlobal': {'booleanValue': false},
      'category': {'stringValue': data['category'] ?? ''},
      'tags': {
        'arrayValue': {'values': []},
      },
      'expiries': {
        'arrayValue': {
          'values': expirationDays != null
              ? [
                  {
                    'mapValue': {
                      'fields': {
                        'quantity': {'integerValue': quantity.toString()},
                        'expirationDate': {
                          'stringValue': now
                              .add(Duration(days: expirationDays))
                              .toIso8601String(),
                        },
                      },
                    },
                  },
                ]
              : [],
        },
      },
    };

    await postToFirestore('products', id.toString(), productMap);
    addedIds.add(id);
  }
  return addedIds;
}

Future<void> seedGlobalProducts() async {
  final productsData = GlobalProductsData.getProducts();

  for (var data in productsData) {
    final id = data['id'] as int;
    final productMap = {
      'id': {'integerValue': id.toString()},
      'name': {'stringValue': data['name']},
      'description': {'stringValue': data['description']},
      'userId': {'stringValue': 'global'},
      'nonExpiringQuantity': {'integerValue': '0'},
      'isGlobal': {'booleanValue': true},
      'category': {'stringValue': data['category'] ?? ''},
      'tags': {
        'arrayValue': {'values': []},
      },
      'expiries': {
        'arrayValue': {'values': []},
      },
    };

    await postToFirestore('products', id.toString(), productMap);
  }
}

Future<void> seedCollections(String userId, List<int> addedProductIds) async {
  final collectionsData = CollectionsData.getCollections();

  for (var data in collectionsData) {
    final id = data['id'] as String;
    final mockProductIds = List<int>.from(data['productIds'] as List);

    // Simplification: just use the mock IDs if they exist in our seeded list
    final actualProductIds = mockProductIds
        .where((mid) => addedProductIds.contains(mid))
        .toList();

    final collectionMap = {
      'id': {'stringValue': id},
      'name': {'stringValue': data['name']},
      'userId': {'stringValue': userId},
      'type': {'stringValue': data['type']},
      'description': {'stringValue': data['description'] ?? ''},
      'productIds': {
        'arrayValue': {
          'values': actualProductIds
              .map((pid) => {'integerValue': pid.toString()})
              .toList(),
        },
      },
    };

    await postToFirestore('collections', id, collectionMap);
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
