// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

import 'auth.dart';

Future<void> main(List<String> args) async {
  print('🚀 Starting Timestamp migration...');

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
    if (!isRemote && !await checkEmulator(client, host, port)) {
      print('❌ Error: Firebase Firestore Emulator is not running.');
      print(
        '   Please run "make start-firebase-emulators" first or set FIRESTORE_REMOTE=true.',
      );
      exit(1);
    }

    print('📦 Fetching all products from $projectId...');
    final products = await getDocuments(
      client,
      projectId,
      host,
      port,
      token,
      isRemote,
      'products',
    );
    print('Found ${products.length} products.');

    int migratedCount = 0;

    for (final product in products) {
      final productId = product['name'].toString().split('/').last;
      final fields = product['fields'] as Map<String, dynamic>? ?? {};

      final expiriesNode = fields['expiries']?['arrayValue'];
      if (expiriesNode == null) continue;

      final expiriesList = expiriesNode['values'] as List<dynamic>? ?? [];
      bool needsMigration = false;

      final updatedExpiries = [];

      for (final expiry in expiriesList) {
        final expiryMap = expiry as Map<String, dynamic>?;
        final expiryFields = expiryMap?['mapValue']?['fields'];
        if (expiryFields is! Map<String, dynamic>) {
          updatedExpiries.add(expiry);
          continue;
        }

        final expirationDateNode = expiryFields['expirationDate'];

        if (expirationDateNode != null &&
            expirationDateNode.containsKey('stringValue')) {
          // It's an ISO string, needs migration
          final isoString = expirationDateNode['stringValue'] as String;

          try {
            final dt = DateTime.parse(isoString).toUtc();
            // Convert to timestamp
            expiryFields['expirationDate'] = {
              'timestampValue': dt.toIso8601String(),
            };
            needsMigration = true;
          } catch (_) {
            print(
              'Warning: Failed to parse date "$isoString" for product $productId',
            );
          }
        }

        updatedExpiries.add({
          'mapValue': {'fields': expiryFields},
        });
      }

      if (needsMigration) {
        print('🔄 Migrating product $productId to use Timestamp...');

        // Prepare patch data
        final updatedFields = Map<String, dynamic>.from(fields);
        updatedFields['expiries'] = {
          'arrayValue': {'values': updatedExpiries},
        };

        await updateDocument(
          client,
          projectId,
          host,
          port,
          token,
          isRemote,
          'products',
          productId,
          updatedFields,
        );
        migratedCount++;
      }
    }

    print(
      '\n✨ Timestamp migration completed successfully! Migrated $migratedCount products.',
    );
  } catch (e) {
    print('❌ Error during migration: $e');
    exit(1);
  } finally {
    client.close();
  }
}

Future<bool> checkEmulator(http.Client client, String host, String port) async {
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

Future<List<dynamic>> getDocuments(
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

Future<void> updateDocument(
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
  final baseUrl = _buildUrl(
    projectId,
    host,
    port,
    isRemote,
    '$collectionPath/$documentId',
  );

  final queryParams = <String, dynamic>{};
  if (fields.isNotEmpty) {
    queryParams['updateMask.fieldPaths'] = fields.keys.toList();
  }

  final uri = Uri.parse(
    baseUrl,
  ).replace(queryParameters: queryParams.isNotEmpty ? queryParams : null);

  final response = await client.patch(
    uri,
    headers: _buildHeaders(isRemote, token),
    body: jsonEncode({'fields': fields}),
  );

  if (response.statusCode != 200) {
    throw Exception(
      'Failed to update document $documentId in $collectionPath: ${response.body}',
    );
  }
}
