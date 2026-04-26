// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

const String projectId = 'demo-project';
const String host = 'localhost';
const String firestorePort = '8080';

Future<void> main() async {
  print('🚀 Starting schema update...');

  final client = http.Client();

  try {
    if (!await checkEmulator(client)) {
      print('❌ Error: Firebase Firestore Emulator is not running.');
      exit(1);
    }

    print('📦 Fetching all products...');
    final products = await getDocuments(client, 'products');
    for (final product in products) {
      final productId = product['name'].toString().split('/').last;
      final fields = product['fields'] as Map<String, dynamic>? ?? {};

      bool needsUpdate = false;
      if (fields.containsKey('expiries')) {
        fields.remove('expiries');
        needsUpdate = true;
      }
      if (fields.containsKey('nonExpiringQuantity')) {
        fields.remove('nonExpiringQuantity');
        needsUpdate = true;
      }
      if (fields.containsKey('quantity')) {
        fields.remove('quantity');
        needsUpdate = true;
      }

      if (needsUpdate) {
        print('🔄 Updating product $productId schema (removing old fields)...');
        await updateDocument(client, 'products', productId, fields);
      }
    }

    print('📦 Fetching all collections...');
    final collections = await getDocuments(client, 'collections');
    for (final collection in collections) {
      final collectionId = collection['name'].toString().split('/').last;
      final fields = collection['fields'] as Map<String, dynamic>? ?? {};

      bool needsUpdate = false;
      if (fields.containsKey('productIds')) {
        fields.remove('productIds');
        needsUpdate = true;
      }

      if (needsUpdate) {
        print(
          '🔄 Updating collection $collectionId schema (removing old fields)...',
        );
        await updateDocument(client, 'collections', collectionId, fields);
      }
    }

    print('\n✨ Schema update completed successfully!');
  } catch (e) {
    print('❌ Error during schema update: $e');
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

Future<List<dynamic>> getDocuments(
  http.Client client,
  String collectionPath,
) async {
  final url =
      'http://$host:$firestorePort/v1/projects/$projectId/databases/(default)/documents/$collectionPath';
  final response = await client.get(Uri.parse(url));

  if (response.statusCode == 200) {
    final data = jsonDecode(response.body);
    return data['documents'] as List<dynamic>? ?? [];
  } else if (response.statusCode == 404) {
    return [];
  } else {
    throw Exception('Failed to fetch documents: ${response.body}');
  }
}

Future<void> updateDocument(
  http.Client client,
  String collectionPath,
  String documentId,
  Map<String, dynamic> fields,
) async {
  // To delete a field via the REST API using patch, we must use the updateMask.
  // The updateMask specifies which fields to update. If a field is in the mask but not in the payload, it gets deleted.
  // Wait, if we just want to replace the whole document, we can issue a PATCH with no updateMask? No, that just merges.
  // Actually, to replace a document completely, we can use the "updateMask" with the fields we want to KEEP.
  // BUT the Firestore REST API `patch` with NO updateMask behaves differently.
  // According to docs, if updateMask is omitted, only the fields present in the document are updated. Fields not present are NOT deleted.
  // To delete fields, we must include them in the updateMask but NOT in the document.
  // Wait, or we can just send the new fields and set the updateMask to the KEYS of the new fields, but that won't delete old fields.
  // To delete fields, we have to list ALL fields we want to keep in the updateMask, and since the old fields are NOT in the mask, they are deleted? No, updateMask defines what is updated. If we want to delete a field, we include it in the updateMask, but omit it from the document payload.

  // However, an easier way to replace the entire document is to DELETE it and POST it again? No, the ID changes with POST. We can DELETE and recreate with specific ID.
  // Or we can just use the updateMask to specify the fields to delete.

  // Let's specify the updateMask with the fields we want to KEEP, and ALSO the fields we want to DELETE?
  // Wait, if a field is in the updateMask, but NOT in the payload, it is deleted.
  // So updateMask should be ALL keys of the OLD document, and payload has the new fields.

  // Actually, if we just use the REST API `patch` with `updateMask` containing ALL existing fields + the ones to delete, the ones missing in payload are deleted.
  // Wait, we don't have the old fields here, just the new fields. Let's just pass `updateMask` with all new fields, plus the deleted fields.
  // But hardcoding the deleted fields might be fragile if they aren't there.
  // Let's just delete the document and recreate it? That's safe and simple.

  final getUrl =
      'http://$host:$firestorePort/v1/projects/$projectId/databases/(default)/documents/$collectionPath/$documentId';
  await client.delete(Uri.parse(getUrl));

  // Now recreate it with the correct ID. To do this, we use POST with `documentId` query param to the parent collection.
  final postUrl =
      'http://$host:$firestorePort/v1/projects/$projectId/databases/(default)/documents/$collectionPath?documentId=$documentId';
  final response = await client.post(
    Uri.parse(postUrl),
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({'fields': fields}),
  );

  if (response.statusCode != 200) {
    throw Exception('Failed to recreate document: ${response.body}');
  }
}
