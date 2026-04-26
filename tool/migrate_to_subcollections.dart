// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

const String projectId = 'demo-project';
const String host = 'localhost';
const String firestorePort = '8080';

Future<void> main() async {
  print('🚀 Starting database migration...');

  final client = http.Client();

  try {
    if (!await checkEmulator(client)) {
      print('❌ Error: Firebase Firestore Emulator is not running.');
      print('   Please run "make start-firebase-emulators" first.');
      exit(1);
    }

    print('📦 Fetching all collections...');
    final collections = await getDocuments(client, 'collections');
    print('Found ${collections.length} collections.');

    for (final collection in collections) {
      final collectionId = collection['name'].toString().split('/').last;
      final fields = collection['fields'] as Map<String, dynamic>? ?? {};
      
      final type = fields['type']?['stringValue'] as String? ?? 'inventory';
      
      final productIdsArray = fields['productIds']?['arrayValue']?['values'] as List<dynamic>? ?? [];
      
      if (productIdsArray.isEmpty) {
        print('  - Collection $collectionId has no products. Skipping.');
        continue;
      }

      print('🔄 Migrating collection $collectionId ($type)...');

      for (final item in productIdsArray) {
        final productId = item['integerValue']?.toString();
        if (productId == null) continue;

        print('  - Fetching product $productId...');
        final product = await getDocument(client, 'products/$productId');
        final productFields = product?['fields'] as Map<String, dynamic>? ?? {};

        if (type == 'shoppingList') {
          // Defaulting shopping list items to count 1
          final shoppingItemFields = {
            'productId': {'integerValue': productId},
            'count': {'integerValue': '1'},
          };
          
          await createDocument(
            client, 
            'collections/$collectionId/shopping_items', 
            productId, 
            shoppingItemFields
          );
        } else {
          // Defaulting inventory items to current expiries
          final expiries = productFields['expiries']?['arrayValue'] ?? {'values': []};
          final nonExpiringQuantity = productFields['nonExpiringQuantity']?['integerValue'] ?? '0';
          
          final inventoryItemFields = {
            'productId': {'integerValue': productId},
            'expiries': {'arrayValue': expiries},
            'nonExpiringQuantity': {'integerValue': nonExpiringQuantity},
          };
          
          await createDocument(
            client, 
            'collections/$collectionId/inventory_items', 
            productId, 
            inventoryItemFields
          );
        }
      }
      
      // Optionally, we could remove the `productIds` field from the collection here,
      // but leaving it might be safer until the UI is fully migrated to use the subcollections.
    }

    print('\n✨ Database migration completed successfully!');
  } catch (e) {
    print('❌ Error during migration: $e');
    exit(1);
  } finally {
    client.close();
  }
}

Future<bool> checkEmulator(http.Client client) async {
  try {
    final response = await client
        .get(Uri.parse('http://$host:$firestorePort/'))
        .timeout(const Duration(seconds: 5));
    return response.statusCode == 200 || response.statusCode == 404;
  } catch (e) {
    return false;
  }
}

Future<List<dynamic>> getDocuments(http.Client client, String collectionPath) async {
  final url = 'http://$host:$firestorePort/v1/projects/$projectId/databases/(default)/documents/$collectionPath';
  final response = await client.get(Uri.parse(url));

  if (response.statusCode == 200) {
    final data = jsonDecode(response.body);
    return data['documents'] as List<dynamic>? ?? [];
  } else if (response.statusCode == 404) {
    return [];
  } else {
    throw Exception('Failed to fetch documents from $collectionPath: ${response.body}');
  }
}

Future<Map<String, dynamic>?> getDocument(http.Client client, String documentPath) async {
  final url = 'http://$host:$firestorePort/v1/projects/$projectId/databases/(default)/documents/$documentPath';
  final response = await client.get(Uri.parse(url));

  if (response.statusCode == 200) {
    return jsonDecode(response.body) as Map<String, dynamic>;
  } else if (response.statusCode == 404) {
    return null;
  } else {
    throw Exception('Failed to fetch document $documentPath: ${response.body}');
  }
}

Future<void> createDocument(http.Client client, String collectionPath, String documentId, Map<String, dynamic> fields) async {
  final url = 'http://$host:$firestorePort/v1/projects/$projectId/databases/(default)/documents/$collectionPath?documentId=$documentId';
  final response = await client.post(
    Uri.parse(url),
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({'fields': fields}),
  );

  // 200 OK or 409 ALREADY_EXISTS (if we patch instead it would be 200)
  if (response.statusCode != 200 && response.statusCode != 409) {
    // If it fails, let's try PATCH (upsert) instead
    final patchUrl = 'http://$host:$firestorePort/v1/projects/$projectId/databases/(default)/documents/$collectionPath/$documentId';
    final patchResponse = await client.patch(
      Uri.parse(patchUrl),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'fields': fields}),
    );
    
    if (patchResponse.statusCode != 200) {
      throw Exception('Failed to create/update document $documentId in $collectionPath: ${patchResponse.body}');
    }
  }
}
