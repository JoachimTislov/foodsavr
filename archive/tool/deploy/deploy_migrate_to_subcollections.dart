// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

import 'auth.dart';

Future<void> main(List<String> args) async {
  print('🚀 Starting subcollections migration...');

  final isRemote = Platform.environment['FIRESTORE_REMOTE'] == 'true';
  final String projectId;
  final String token;

  if (isRemote) {
    projectId = await getProjectId();
    token = await getToken();
  } else {
    projectId = Platform.environment['FIREBASE_PROJECT_ID'] ?? 'demo-project';
    token = 'ya29.a.mock-token';
  }

  final host =
      Platform.environment['FIRESTORE_HOST'] ??
      (isRemote ? 'firestore.googleapis.com' : 'localhost');
  final port =
      Platform.environment['FIRESTORE_PORT'] ?? (isRemote ? '443' : '8080');

  final client = http.Client();

  try {
    if (!isRemote && !await _checkEmulator(client, host, port)) {
      print('❌ Error: Firebase Firestore Emulator is not running.');
      print(
        '   Please run "make start-firebase-emulators" first or set FIRESTORE_REMOTE=true.',
      );
      exit(1);
    }

    print('📦 Fetching all collections from $projectId...');
    final collections = await _getDocuments(
      client,
      projectId,
      host,
      port,
      token,
      isRemote,
      'collections',
    );
    print('Found ${collections.length} collections.');

    int migratedItemsCount = 0;

    for (final collection in collections) {
      final collectionId = collection['name'].toString().split('/').last;
      final fields = collection['fields'] as Map<String, dynamic>? ?? {};
      final type = fields['type']?['stringValue'] as String?;

      if (type != 'inventory' && type != 'shopping') {
        print(
          '   ⚠️  Skipping collection $collectionId: unknown or missing type ($type).',
        );
        continue;
      }

      final productIdsNode = fields['productIds']?['arrayValue'];

      if (productIdsNode == null) continue;

      final productIdsList = productIdsNode['values'] as List<dynamic>? ?? [];

      for (final pidEntry in productIdsList) {
        final productIdStr = pidEntry['stringValue'] as String?;
        if (productIdStr == null) continue;

        // Fetch the product to get its expiries
        final productDoc = await _getDocument(
          client,
          projectId,
          host,
          port,
          token,
          isRemote,
          'products/$productIdStr',
        );

        if (productDoc == null) {
          print(
            '   ⚠️  Skipping missing product "$productIdStr" referenced by collection $collectionId.',
          );
          continue;
        }

        final productFields =
            productDoc['fields'] as Map<String, dynamic>? ?? {};
        final rawId =
            productFields['id']?['integerValue']?.toString() ?? productIdStr;
        final productIdInt = int.tryParse(rawId);

        if (productIdInt == null) {
          print(
            '   ⚠️  Skipping product "$productIdStr" in collection $collectionId: non-numeric id "$rawId".',
          );
          continue;
        }

        if (type == 'inventory') {
          // Migrate to inventory_items
          final expiriesNode = productFields['expiries'];
          final targetFields = {
            'productId': {'integerValue': productIdInt.toString()},
          };
          if (expiriesNode != null) {
            targetFields['expiries'] = expiriesNode;
          }

          await _createDocument(
            client,
            projectId,
            host,
            port,
            token,
            isRemote,
            'collections/$collectionId/inventory_items',
            productIdStr,
            targetFields,
          );
          migratedItemsCount++;
        } else if (type == 'shopping') {
          // Migrate to shopping_items
          final targetFields = {
            'productId': {'integerValue': productIdInt.toString()},
            'count': {'integerValue': '1'},
          };

          await _createDocument(
            client,
            projectId,
            host,
            port,
            token,
            isRemote,
            'collections/$collectionId/shopping_items',
            productIdStr,
            targetFields,
          );
          migratedItemsCount++;
        }
      }
    }

    print(
      '\n✨ Migration to subcollections completed successfully! Migrated $migratedItemsCount items.',
    );
    print(
      'You can now run `dart run tool/update_schema.dart` to remove legacy fields.',
    );
  } catch (e) {
    print('❌ Error during migration: $e');
    exit(1);
  } finally {
    client.close();
  }
}

Future<bool> _checkEmulator(
  http.Client client,
  String host,
  String port,
) async {
  try {
    final response = await client
        .get(Uri.parse('http://$host:$port/'))
        .timeout(const Duration(seconds: 5));
    return response.statusCode == 200 || response.statusCode == 404;
  } catch (e) {
    return false;
  }
}

String _buildUrl(
  String projectId,
  String host,
  String port,
  bool isRemote,
  String path,
) {
  final scheme = isRemote ? 'https' : 'http';
  final portPart = (isRemote && port == '443') ? '' : ':$port';
  return '$scheme://$host$portPart/v1/projects/$projectId/databases/(default)/documents/$path';
}

Map<String, String> _buildHeaders(bool isRemote, String token) {
  final headers = {'Content-Type': 'application/json'};
  if (isRemote) {
    headers['Authorization'] = 'Bearer $token';
  }
  return headers;
}

Future<List<dynamic>> _getDocuments(
  http.Client client,
  String projectId,
  String host,
  String port,
  String token,
  bool isRemote,
  String collectionPath,
) async {
  final baseUrl = _buildUrl(projectId, host, port, isRemote, collectionPath);
  final List<dynamic> allDocuments = [];
  String? pageToken;

  do {
    final queryParams = {'pageSize': '1000'};
    if (pageToken != null && pageToken.isNotEmpty) {
      queryParams['pageToken'] = pageToken;
    }
    final uri = Uri.parse(baseUrl).replace(queryParameters: queryParams);

    final response = await client.get(
      uri,
      headers: _buildHeaders(isRemote, token),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final docs = data['documents'] as List<dynamic>? ?? [];
      allDocuments.addAll(docs);
      pageToken = data['nextPageToken'] as String?;
    } else if (response.statusCode == 404) {
      break;
    } else {
      throw Exception(
        'Failed to fetch documents from $collectionPath: ${response.body}',
      );
    }
  } while (pageToken != null && pageToken.isNotEmpty);

  return allDocuments;
}

Future<Map<String, dynamic>?> _getDocument(
  http.Client client,
  String projectId,
  String host,
  String port,
  String token,
  bool isRemote,
  String docPath,
) async {
  final url = _buildUrl(projectId, host, port, isRemote, docPath);
  final response = await client.get(
    Uri.parse(url),
    headers: _buildHeaders(isRemote, token),
  );

  if (response.statusCode == 200) {
    return jsonDecode(response.body) as Map<String, dynamic>;
  } else if (response.statusCode == 404) {
    return null;
  } else {
    throw Exception('Failed to fetch document $docPath: ${response.body}');
  }
}

Future<void> _createDocument(
  http.Client client,
  String projectId,
  String host,
  String port,
  String token,
  bool isRemote,
  String collectionPath,
  String documentId,
  Map<String, dynamic> fields,
) async {
  final url = _buildUrl(
    projectId,
    host,
    port,
    isRemote,
    '$collectionPath?documentId=${Uri.encodeQueryComponent(documentId)}',
  );

  // Use POST to create document. If it already exists, Firestore REST returns 409 Conflict.
  final response = await client.post(
    Uri.parse(url),
    headers: _buildHeaders(isRemote, token),
    body: jsonEncode({'fields': fields}),
  );

  if (response.statusCode != 200 && response.statusCode != 409) {
    // If it's a 409, it means it already exists, which is fine for migration idempotency.
    throw Exception(
      'Failed to create document $documentId in $collectionPath: ${response.body}',
    );
  }
}
