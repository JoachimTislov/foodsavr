import 'dart:convert';
import 'dart:io';

Future<String?> _getEnvOrFile(
  String envKey,
  String filePath,
  String? Function(Map<String, dynamic> json) extractFromJson,
) async {
  final env = Platform.environment[envKey];
  if (env != null && env.isNotEmpty) return env;

  final file = File(filePath);
  if (await file.exists()) {
    try {
      final content = await file.readAsString();
      final json = jsonDecode(content);
      if (json is Map<String, dynamic>) {
        final extracted = extractFromJson(json);
        if (extracted != null && extracted.isNotEmpty) {
          return extracted;
        }
      }
    } catch (_) {}
  }
  return null;
}

Future<String> getProjectId() async {
  final val = await _getEnvOrFile(
    'FIREBASE_PROJECT_ID',
    '.firebaserc',
    (json) {
      final projects = json['projects'] as Map<String, dynamic>?;
      if (projects != null) {
        if (projects.containsKey('default')) {
          return projects['default'] as String;
        } else if (projects.isNotEmpty) {
          return projects.values.first as String;
        }
      }
      return null;
    },
  );

  if (val != null) return val;

  final result = await Process.run('gcloud', ['config', 'get-value', 'project']);
  if (result.exitCode == 0) {
    final proj = result.stdout.toString().trim();
    if (proj.isNotEmpty) return proj;
  }

  throw Exception('Could not determine Firebase project ID.');
}

Future<String> getToken() async {
  final env = Platform.environment['FIREBASE_TOKEN'];
  if (env != null && env.isNotEmpty) return env;

  final result = await Process.run('gcloud', ['auth', 'print-access-token']);
  if (result.exitCode == 0) {
    final token = result.stdout.toString().trim();
    if (token.isNotEmpty) return token;
  }

  throw Exception(
    'Could not determine Firebase token. Please run `gcloud auth print-access-token` or set FIREBASE_TOKEN.',
  );
}

Future<String> getRulesPath() async {
  final val = await _getEnvOrFile(
    'FIRESTORE_RULES_PATH',
    'firebase.json',
    (json) {
      final firestore = json['firestore'];
      if (firestore is Map && firestore.containsKey('rules')) {
        return firestore['rules'] as String;
      }
      return null;
    },
  );

  if (val != null) return val;

  return 'firestore.rules';
}
