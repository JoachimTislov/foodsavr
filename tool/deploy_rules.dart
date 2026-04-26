// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

Future<void> main(List<String> args) async {
  print('🚀 Starting Firestore Rules Deployment...');

  final projectId =
      Platform.environment['FIREBASE_PROJECT_ID'] ?? 'demo-project';
  final token = Platform.environment['FIREBASE_TOKEN'] ?? '';
  final rulesFile =
      Platform.environment['FIRESTORE_RULES_PATH'] ?? 'firestore.rules';

  if (token.isEmpty) {
    print('❌ Error: FIREBASE_TOKEN environment variable is required.');
    print('   Use `gcloud auth print-access-token` to get a token.');
    exit(1);
  }

  final file = File(rulesFile);
  if (!await file.exists()) {
    print('❌ Error: Rules file "$rulesFile" not found.');
    exit(1);
  }

  final rulesContent = await file.readAsString();
  if (rulesContent.trim().isEmpty) {
    print('❌ Error: Rules file "$rulesFile" is empty.');
    exit(1);
  }
  final client = http.Client();

  try {
    print('📦 Creating Ruleset for $projectId...');
    final rulesetName = await createRuleset(
      client,
      projectId,
      token,
      rulesContent,
    );
    print('✅ Ruleset created: $rulesetName');

    print('🚀 Updating Release "cloud.firestore"...');
    await updateRelease(client, projectId, token, rulesetName);
    print('✅ Successfully deployed Firestore rules to $projectId!');
  } catch (e) {
    print('❌ Error deploying rules: $e');
    exit(1);
  } finally {
    client.close();
  }
}

Future<String> createRuleset(
  http.Client client,
  String projectId,
  String token,
  String content,
) async {
  final url = Uri.parse(
    'https://firebaserules.googleapis.com/v1/projects/$projectId/rulesets',
  );
  final body = {
    'source': {
      'files': [
        {'name': 'firestore.rules', 'content': content},
      ],
    },
  };

  final response = await client.post(
    url,
    headers: {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    },
    body: jsonEncode(body),
  );

  if (response.statusCode == 200) {
    final data = jsonDecode(response.body);
    return data['name'] as String;
  } else {
    throw Exception(
      'Failed to create ruleset: ${response.statusCode} - ${response.body}',
    );
  }
}

Future<void> updateRelease(
  http.Client client,
  String projectId,
  String token,
  String rulesetName,
) async {
  final releaseName = 'projects/$projectId/releases/cloud.firestore';
  final url = Uri.parse('https://firebaserules.googleapis.com/v1/$releaseName');

  final body = {'name': releaseName, 'rulesetName': rulesetName};

  var response = await client.patch(
    url,
    headers: {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    },
    body: jsonEncode(body),
  );

  if (response.statusCode == 404) {
    print('   Release does not exist. Creating new release...');
    final createUrl = Uri.parse(
      'https://firebaserules.googleapis.com/v1/projects/$projectId/releases',
    );
    response = await client.post(
      createUrl,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(body),
    );
  }

  if (response.statusCode != 200) {
    throw Exception(
      'Failed to update release: ${response.statusCode} - ${response.body}',
    );
  }
}
