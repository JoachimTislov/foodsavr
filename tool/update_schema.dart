// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

Future<void> main(List<String> args) async {
  print('🚀 Starting schema update...');

  final isRemote = Platform.environment['FIRESTORE_REMOTE'] == 'true';
  final projectId =
      Platform.environment['FIREBASE_PROJECT_ID'] ?? 'demo-project';
  final host =
      Platform.environment['FIRESTORE_HOST'] ??
      (isRemote ? 'firestore.googleapis.com' : 'localhost');
  final port =
      Platform.environment['FIRESTORE_PORT'] ?? (isRemote ? '443' : '8080');
  final token = Platform.environment['FIREBASE_TOKEN'] ?? '';

  if (isRemote && token.isEmpty) {
    print(
      '❌ Error: FIREBASE_TOKEN environment variable is required when FIRESTORE_REMOTE=true.',
    );
    print('   Use `gcloud auth print-access-token` to get a token.');
    exit(1);
  }

  final client = http.Client();

  try {
    if (!isRemote && !await checkEmulator(client, host, port)) {
      print('❌ Error: Firebase Firestore Emulator is not running.');
      print(
        '   Please run "make start-firebase-emulators" first or set FIRESTORE_REMOTE=true.',
      );
      exit(1);
    }

    print('📦 Fetching all products...');
    final products = await getDocuments(
      client,
      projectId,
      host,
      port,
      token,
      isRemote,
      'products',
    );
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
        await updateDocument(
          client,
          projectId,
          host,
          port,
          token,
          isRemote,
          'products',
          productId,
          fields,
        );
      }
    }

    print('📦 Fetching all collections...');
    final collections = await getDocuments(
      client,
      projectId,
      host,
      port,
      token,
      isRemote,
      'collections',
    );
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
        await updateDocument(
          client,
          projectId,
          host,
          port,
          token,
          isRemote,
          'collections',
          collectionId,
          fields,
        );
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
  final url = _buildUrl(projectId, host, port, isRemote, collectionPath);
  final response = await client.get(
    Uri.parse(url),
    headers: _buildHeaders(isRemote, token),
  );

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
  String projectId,
  String host,
  String port,
  String token,
  bool isRemote,
  String collectionPath,
  String documentId,
  Map<String, dynamic> fields,
) async {
  // To completely replace the document with only the provided fields, we DELETE and POST
  final getUrl = _buildUrl(
    projectId,
    host,
    port,
    isRemote,
    '$collectionPath/$documentId',
  );
  await client.delete(
    Uri.parse(getUrl),
    headers: _buildHeaders(isRemote, token),
  );

  final postUrl =
      '${_buildUrl(projectId, host, port, isRemote, collectionPath)}?documentId=$documentId';
  final response = await client.post(
    Uri.parse(postUrl),
    headers: _buildHeaders(isRemote, token),
    body: jsonEncode({'fields': fields}),
  );

  if (response.statusCode != 200) {
    throw Exception('Failed to recreate document: ${response.body}');
  }
}
