// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

const String projectId = 'demo-project';
const String host = 'localhost';
const String firestorePort = '8080';

Future<void> main() async {
  print('🚀 Starting Timestamp migration...');

  final client = http.Client();

  try {
    if (!await checkEmulator(client)) {
      print('❌ Error: Firebase Firestore Emulator is not running.');
      print('   Please run "make start-firebase-emulators" first.');
      exit(1);
    }

    print('📦 Fetching all products...');
    final products = await getDocuments(client, 'products');
    print('Found ${products.length} products.');

    for (final product in products) {
      final productId = product['name'].toString().split('/').last;
      final fields = product['fields'] as Map<String, dynamic>? ?? {};
      
      final expiriesNode = fields['expiries']?['arrayValue'];
      if (expiriesNode == null) continue;
      
      final expiriesList = expiriesNode['values'] as List<dynamic>? ?? [];
      bool needsMigration = false;
      
      final updatedExpiries = [];

      for (final expiry in expiriesList) {
        final expiryFields = expiry['mapValue']?['fields'] as Map<String, dynamic>? ?? {};
        final expirationDateNode = expiryFields['expirationDate'];
        
        if (expirationDateNode != null && expirationDateNode.containsKey('stringValue')) {
          // It's an ISO string, needs migration
          final isoString = expirationDateNode['stringValue'] as String;
          needsMigration = true;
          
          // Convert to timestamp
          expiryFields['expirationDate'] = {
            'timestampValue': isoString.endsWith('Z') ? isoString : '${isoString}Z'
          };
        }
        
        updatedExpiries.add({
          'mapValue': {
            'fields': expiryFields
          }
        });
      }

      if (needsMigration) {
        print('🔄 Migrating product $productId to use Timestamp...');
        
        // Prepare patch data
        final updatedFields = Map<String, dynamic>.from(fields);
        updatedFields['expiries'] = {
          'arrayValue': {
            'values': updatedExpiries
          }
        };

        await updateDocument(client, 'products', productId, updatedFields);
      }
    }

    print('\n✨ Timestamp migration completed successfully!');
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

Future<void> updateDocument(http.Client client, String collectionPath, String documentId, Map<String, dynamic> fields) async {
  final url = 'http://$host:$firestorePort/v1/projects/$projectId/databases/(default)/documents/$collectionPath/$documentId';
  final response = await client.patch(
    Uri.parse(url),
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({'fields': fields}),
  );

  if (response.statusCode != 200) {
    throw Exception('Failed to update document $documentId in $collectionPath: ${response.body}');
  }
}
