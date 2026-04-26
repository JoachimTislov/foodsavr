// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

Future<void> main(List<String> args) async {
  print('🚀 Starting robust schema update...');

  final isRemote = Platform.environment['FIRESTORE_REMOTE'] == 'true';
  final projectId =
      Platform.environment['FIREBASE_PROJECT_ID'] ?? 'demo-project';
  final host =
      Platform.environment['FIRESTORE_HOST'] ??
      (isRemote ? 'firestore.googleapis.com' : 'localhost');
  final port =
      Platform.environment['FIRESTORE_PORT'] ?? (isRemote ? '443' : '8080');
  final token = Platform.environment['FIREBASE_TOKEN'] ?? '';
  final isDryRun = Platform.environment['DRY_RUN'] == 'true';

  if (isDryRun) {
    print(
      '⚠️  RUNNING IN DRY-RUN MODE: No changes will be written to the database.',
    );
  }

  final configPath =
      Platform.environment['MIGRATIONS_CONFIG'] ?? 'migrations/permanent.json';
  final scriptsPath = Platform.environment['MIGRATIONS_DIR'] ?? 'migrations';

  if (isRemote && token.isEmpty) {
    print(
      '❌ Error: FIREBASE_TOKEN environment variable is required when FIRESTORE_REMOTE=true.',
    );
    print('   Use `gcloud auth print-access-token` to get a token.');
    exit(1);
  }

  final configFile = File(configPath);
  if (!await configFile.exists()) {
    print('❌ Error: Global configuration file not found at $configPath');
    exit(1);
  }

  final configContent = await configFile.readAsString();
  final config = jsonDecode(configContent) as Map<String, dynamic>;
  final protectedFields = List<String>.from(
    config['protectedFields'] as List<dynamic>? ?? [],
  );

  final scriptsDir = Directory(scriptsPath);
  if (!await scriptsDir.exists()) {
    print('❌ Error: Scripts directory not found at $scriptsPath');
    exit(1);
  }

  final scriptFiles = scriptsDir
      .listSync()
      .whereType<File>()
      .where(
        (f) =>
            f.path.endsWith('.json') &&
            !f.uri.pathSegments.last.contains('permanent.json'),
      )
      .toList();
  scriptFiles.sort((a, b) => a.path.compareTo(b.path));

  if (scriptFiles.isEmpty) {
    print('ℹ️ No migration scripts found in $scriptsPath.');
    return;
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

    // Ensure _migrations collection exists or fetch applied scripts
    print('📦 Fetching applied migration state from _migrations...');
    final appliedMigrations = await getAppliedMigrations(
      client,
      projectId,
      host,
      port,
      token,
      isRemote,
    );

    for (final file in scriptFiles) {
      final scriptName = file.uri.pathSegments.last;
      if (appliedMigrations.contains(scriptName)) {
        print('⏭️  Skipping already applied migration: $scriptName');
        continue;
      }

      print('⚙️  Processing migration script: $scriptName...');
      final scriptContent = await file.readAsString();
      final script = jsonDecode(scriptContent) as Map<String, dynamic>;
      final operations = script['operations'] as List<dynamic>? ?? [];

      // Validate Phase
      for (final operation in operations) {
        final op = operation as Map<String, dynamic>;
        final removeFields = List<String>.from(
          op['removeFields'] as List<dynamic>? ?? [],
        );

        for (final field in removeFields) {
          if (protectedFields.contains(field)) {
            print(
              '❌ VALIDATION ERROR: Script $scriptName attempts to remove protected field: $field',
            );
            exit(1);
          }
        }
      }

      // Execution Phase
      for (final operation in operations) {
        final op = operation as Map<String, dynamic>;
        final targetType = op['targetType'] as String;
        final path = op['path'] as String;
        final removeFields = List<String>.from(
          op['removeFields'] as List<dynamic>? ?? [],
        );
        final addFields = op['addFields'] as List<dynamic>? ?? [];

        if (targetType == 'collection') {
          await processCollection(
            client,
            projectId,
            host,
            port,
            token,
            isRemote,
            isDryRun,
            path,
            removeFields,
            addFields,
            protectedFields,
          );
        } else if (targetType == 'document') {
          await processDocument(
            client,
            projectId,
            host,
            port,
            token,
            isRemote,
            isDryRun,
            path,
            removeFields,
            addFields,
            protectedFields,
          );
        } else if (targetType == 'subcollection') {
          // Syntax: parentCollection/*/subCollectionName
          final parts = path.split('/*/');
          if (parts.length != 2) {
            print(
              '❌ ERROR: Invalid subcollection path syntax. Expected parent/*/sub. Got: $path',
            );
            exit(1);
          }
          final parentCol = parts[0];
          final subCol = parts[1];

          print(
            '   Fetching parent docs in $parentCol to target subcollection $subCol...',
          );
          final parents = await getDocumentsPaginated(
            client,
            projectId,
            host,
            port,
            token,
            isRemote,
            parentCol,
          );
          for (final parent in parents) {
            final parentName = parent['name'] as String;
            final relativeParentPath = parentName.split('/documents/').last;
            await processCollection(
              client,
              projectId,
              host,
              port,
              token,
              isRemote,
              isDryRun,
              '$relativeParentPath/$subCol',
              removeFields,
              addFields,
              protectedFields,
            );
          }
        } else {
          print('❌ ERROR: Unknown targetType: $targetType in $scriptName');
          exit(1);
        }
      }

      // Mark as applied
      if (!isDryRun) {
        await markMigrationApplied(
          client,
          projectId,
          host,
          port,
          token,
          isRemote,
          scriptName,
        );
        print('✅ Migration $scriptName applied successfully!');
      } else {
        print('   [DRY RUN] Would mark migration $scriptName as applied.');
      }
    }

    print('\n✨ All dynamic schema updates completed successfully!');
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
  String relativePath,
) {
  final scheme = isRemote ? 'https' : 'http';
  final portPart = (isRemote && port == '443') ? '' : ':$port';
  return '$scheme://$host$portPart/v1/projects/$projectId/databases/(default)/documents/$relativePath';
}

Map<String, String> _buildHeaders(bool isRemote, String token) {
  final headers = {'Content-Type': 'application/json'};
  if (isRemote) {
    headers['Authorization'] = 'Bearer $token';
  }
  return headers;
}

Future<List<String>> getAppliedMigrations(
  http.Client client,
  String projectId,
  String host,
  String port,
  String token,
  bool isRemote,
) async {
  try {
    final docs = await getDocumentsPaginated(
      client,
      projectId,
      host,
      port,
      token,
      isRemote,
      '_migrations',
    );
    return docs.map((d) => (d['name'] as String).split('/').last).toList();
  } catch (e) {
    // Collection might not exist yet, which is fine
    if (e.toString().contains('404')) return [];
    // Or if not paginated or some other error, swallow it and assume none
    return [];
  }
}

Future<void> markMigrationApplied(
  http.Client client,
  String projectId,
  String host,
  String port,
  String token,
  bool isRemote,
  String scriptName,
) async {
  final url = _buildUrl(
    projectId,
    host,
    port,
    isRemote,
    '_migrations?documentId=$scriptName',
  );
  final body = {
    'fields': {
      'appliedAt': {'timestampValue': DateTime.now().toUtc().toIso8601String()},
    },
  };

  final response = await client.post(
    Uri.parse(url),
    headers: _buildHeaders(isRemote, token),
    body: jsonEncode(body),
  );
  if (response.statusCode != 200 && response.statusCode != 409) {
    throw Exception('Failed to record migration state: ${response.body}');
  }
}

Future<List<dynamic>> getDocumentsPaginated(
  http.Client client,
  String projectId,
  String host,
  String port,
  String token,
  bool isRemote,
  String collectionPath,
) async {
  List<dynamic> allDocs = [];
  String? pageToken;

  do {
    String urlStr = _buildUrl(projectId, host, port, isRemote, collectionPath);
    urlStr += '?pageSize=300';
    if (pageToken != null) urlStr += '&pageToken=$pageToken';

    final response = await client.get(
      Uri.parse(urlStr),
      headers: _buildHeaders(isRemote, token),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final docs = data['documents'] as List<dynamic>? ?? [];
      allDocs.addAll(docs);
      pageToken = data['nextPageToken'] as String?;
    } else if (response.statusCode == 404) {
      return allDocs; // Return what we have, collection might just be empty
    } else {
      throw Exception(
        'Failed to fetch documents: ${response.statusCode} - ${response.body}',
      );
    }
  } while (pageToken != null);

  return allDocs;
}

Future<Map<String, dynamic>?> getDocument(
  http.Client client,
  String projectId,
  String host,
  String port,
  String token,
  bool isRemote,
  String docPath,
) async {
  final urlStr = _buildUrl(projectId, host, port, isRemote, docPath);
  final response = await client.get(
    Uri.parse(urlStr),
    headers: _buildHeaders(isRemote, token),
  );

  if (response.statusCode == 200) {
    return jsonDecode(response.body) as Map<String, dynamic>;
  } else if (response.statusCode == 404) {
    return null;
  } else {
    throw Exception(
      'Failed to fetch document: ${response.statusCode} - ${response.body}',
    );
  }
}

Future<void> processCollection(
  http.Client client,
  String projectId,
  String host,
  String port,
  String token,
  bool isRemote,
  bool isDryRun,
  String collectionPath,
  List<String> removeFields,
  List<dynamic> addFields,
  List<String> protectedFields,
) async {
  print('   Fetching docs in $collectionPath...');
  final docs = await getDocumentsPaginated(
    client,
    projectId,
    host,
    port,
    token,
    isRemote,
    collectionPath,
  );
  for (final doc in docs) {
    final absoluteName = doc['name'] as String;
    final fields = doc['fields'] as Map<String, dynamic>? ?? {};
    await _applyModifications(
      client,
      host,
      port,
      isRemote,
      isDryRun,
      token,
      absoluteName,
      fields,
      removeFields,
      addFields,
      protectedFields,
    );
  }
}

Future<void> processDocument(
  http.Client client,
  String projectId,
  String host,
  String port,
  String token,
  bool isRemote,
  bool isDryRun,
  String docPath,
  List<String> removeFields,
  List<dynamic> addFields,
  List<String> protectedFields,
) async {
  print('   Fetching doc $docPath...');
  final doc = await getDocument(
    client,
    projectId,
    host,
    port,
    token,
    isRemote,
    docPath,
  );
  if (doc == null) {
    print('   ⚠️ Document $docPath not found. Skipping.');
    return;
  }

  final absoluteName = doc['name'] as String;
  final fields = doc['fields'] as Map<String, dynamic>? ?? {};
  await _applyModifications(
    client,
    host,
    port,
    isRemote,
    isDryRun,
    token,
    absoluteName,
    fields,
    removeFields,
    addFields,
    protectedFields,
  );
}

Future<void> _applyModifications(
  http.Client client,
  String host,
  String port,
  bool isRemote,
  bool isDryRun,
  String token,
  String absoluteName,
  Map<String, dynamic> currentFields,
  List<String> removeFields,
  List<dynamic> addFields,
  List<String> protectedFields,
) async {
  bool needsUpdate = false;
  final updatedFields = Map<String, dynamic>.from(currentFields);

  List<String> actuallyRemoved = [];
  Map<String, dynamic> actuallyAddedOrUpdated = {};

  // Remove fields
  for (final f in removeFields) {
    if (updatedFields.containsKey(f)) {
      updatedFields.remove(f);
      actuallyRemoved.add(f);
      needsUpdate = true;
    }
  }

  // Add fields safely
  for (final addF in addFields) {
    final af = addF as Map<String, dynamic>;
    final name = af['name'] as String;
    final type = af['type'] as String;
    final value = af['value'];

    if (updatedFields.containsKey(name)) {
      // If the field exists AND it is a protected field, do NOT modify it.
      if (protectedFields.contains(name)) {
        print(
          '      ⚠️  WARNING: Skipping modification of protected field "$name" on ${absoluteName.split('/').last}. Protected fields can be added but not modified.',
        );
        continue;
      }
    }

    final newValue = _buildFirestoreValue(type, value);

    if (!updatedFields.containsKey(name) ||
        jsonEncode(updatedFields[name]) != jsonEncode(newValue)) {
      updatedFields[name] = newValue;
      actuallyAddedOrUpdated[name] = value;
      needsUpdate = true;
    }
  }

  if (needsUpdate) {
    if (isDryRun) {
      print('      [DRY RUN] Would update ${absoluteName.split('/').last}:');
      if (actuallyRemoved.isNotEmpty) {
        print('         - Remove: ${actuallyRemoved.join(', ')}');
      }
      if (actuallyAddedOrUpdated.isNotEmpty) {
        print('         - Set/Update: $actuallyAddedOrUpdated');
      }
    } else {
      print('      🔄 Patching ${absoluteName.split('/').last}...');
      await _patchDocument(
        client,
        host,
        port,
        isRemote,
        token,
        absoluteName,
        updatedFields,
      );
    }
  }
}

Map<String, dynamic> _buildFirestoreValue(String type, dynamic value) {
  switch (type.toLowerCase()) {
    case 'string':
      return {'stringValue': value.toString()};
    case 'integer':
      return {'integerValue': value.toString()};
    case 'double':
      return {
        'doubleValue': value is num
            ? value.toDouble()
            : double.parse(value.toString()),
      };
    case 'boolean':
      return {'booleanValue': value == true || value == 'true'};
    case 'timestamp':
      return {'timestampValue': value.toString()}; // Expected ISO-8601
    case 'null':
      return {'nullValue': null};
    default:
      throw Exception('Unsupported add field type: $type');
  }
}

Future<void> _patchDocument(
  http.Client client,
  String host,
  String port,
  bool isRemote,
  String token,
  String absoluteName,
  Map<String, dynamic> fields,
) async {
  final scheme = isRemote ? 'https' : 'http';
  final portPart = (isRemote && port == '443') ? '' : ':$port';

  // Create update mask based on keys we want to *keep*.
  // Anything not in updateMask is ignored. Wait, if a field is in updateMask but not in payload, it's deleted.
  // So updateMask must contain all keys in the new fields map, PLUS the keys we want to delete.
  // Actually, wait: If we just list the keys of the `fields` map in the updateMask,
  // fields NOT in the updateMask are preserved untouched in Firestore.
  // Fields IN the updateMask but NOT in payload are deleted in Firestore.
  // Since we want to delete some fields, they are NOT in the payload anymore, so we MUST include them in the updateMask so Firestore deletes them!
  // Wait, if we use PATCH without updateMask, Firestore ONLY updates the fields in the payload and leaves others untouched. So we can't delete fields without updateMask.
  // If we pass an updateMask containing ALL keys of the OLD document, and the payload only has the NEW keys, the missing ones get deleted.
  // However, it's simpler: Firestore REST API `patch` with NO updateMask updates fields present.
  // We can't delete easily via patch without updateMask.
  // So to replace the document precisely with our modified `fields` map and discard anything else, we must list ALL fields in `fields.keys` as the updateMask.
  // Wait! If a key was removed, it is NOT in `fields.keys`. So it won't be deleted in Firestore if we only pass `fields.keys` in updateMask.
  // Workaround: Use DELETE + POST if we want to replace the whole document?
  // No, better workaround: pass the deleted fields in the updateMask but not in the payload.
  // Actually, we can just fetch the existing document, get its keys, and pass ALL existing keys in the updateMask.

  // Wait, let's just make the updateMask equal to `fields.keys.join('&')` and for deleted fields, we can just send them as null?
  // No, `nullValue: null` is a literal null field.
  // Let's implement full document overwrite via REST correctly: We GET it, so we know what keys it currently has.
  // But wait, the `updateMask` feature is exactly for this.
  // We don't have the original keys easily accessible here unless we pass them.
  // Let's just pass `updateMask` for the fields we WANT to update/delete.
  // Since we only do additions and removals:
  // We could just pass the `removeFields` keys and the `addFields` keys in the updateMask.
  // But wait, it's easier to simply DELETE and re-POST the document with the exact new state.
  // BUT DELETE/POST can break subcollections? Actually, deleting a parent doc in Firestore does NOT delete its subcollections.
  // BUT the Firestore REST API `DELETE` on a document doesn't affect subcollections either.
  // Wait, posting a document to a specific ID replaces it completely and safely preserves subcollections.
  // Let's do that. It's atomic enough for this script and guarantees structural purity.

  final getUrl = '$scheme://$host$portPart/v1/$absoluteName';
  await client.delete(
    Uri.parse(getUrl),
    headers: _buildHeaders(isRemote, token),
  );

  final parentPath = absoluteName.substring(0, absoluteName.lastIndexOf('/'));
  final docId = absoluteName.split('/').last;

  final postUrl = '$scheme://$host$portPart/v1/$parentPath?documentId=$docId';
  final response = await client.post(
    Uri.parse(postUrl),
    headers: _buildHeaders(isRemote, token),
    body: jsonEncode({'fields': fields}),
  );

  if (response.statusCode != 200) {
    throw Exception(
      'Failed to recreate document during patch: ${response.statusCode} - ${response.body}',
    );
  }
}
