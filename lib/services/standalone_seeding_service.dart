import 'dart:convert';
import 'package:http/http.dart' as http;

class SeedRecord {
  final String collectionPath;
  final String documentId;
  final Map<String, dynamic> firestoreRestFields;

  SeedRecord(this.collectionPath, this.documentId, this.firestoreRestFields);
}

/// Service to handle database seeding for the Firebase Emulator and Remote via REST API.
class StandaloneSeedingService {
  final String projectId;
  final String host;
  final String authPort;
  final String firestorePort;
  final String apiKey;
  final bool isRemote;
  final http.Client client;

  String? _idToken;

  StandaloneSeedingService({
    required this.projectId,
    this.host = 'localhost',
    this.authPort = '9099',
    this.firestorePort = '8080',
    this.apiKey = 'fake-key',
    this.isRemote = false,
    http.Client? client,
  }) : client = client ?? http.Client();

  String get _authBaseUrl {
    if (isRemote) {
      return 'https://identitytoolkit.googleapis.com';
    }
    return 'http://$host:$authPort/identitytoolkit.googleapis.com';
  }

  String get _firestoreBaseUrl {
    if (isRemote) {
      return 'https://firestore.googleapis.com/v1/projects/$projectId/databases/(default)/documents';
    }
    return 'http://$host:$firestorePort/v1/projects/$projectId/databases/(default)/documents';
  }

  /// Checks if the Firebase Emulators are running.
  Future<bool> checkEmulators() async {
    if (isRemote) return true;
    try {
      final results = await Future.wait([
        client
            .get(Uri.parse('http://$host:$firestorePort/'))
            .timeout(const Duration(seconds: 5)),
        client
            .get(Uri.parse('http://$host:$authPort/'))
            .timeout(const Duration(seconds: 5)),
      ]);
      return results.every((r) => r.statusCode == 200 || r.statusCode == 404);
    } catch (e) {
      return false;
    }
  }

  /// Creates a test user or signs in if already exists.
  Future<String> createTestUser(String email, String password) async {
    final url = '$_authBaseUrl/v1/accounts:signUp?key=$apiKey';
    final response = await client
        .post(
          Uri.parse(url),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'email': email,
            'password': password,
            'returnSecureToken': true,
          }),
        )
        .timeout(const Duration(seconds: 5));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      _idToken = data['idToken'];
      return data['localId'];
    } else {
      final error = jsonDecode(response.body)['error'];
      if (error != null && error['message'] == 'EMAIL_EXISTS') {
        final signInUrl =
            '$_authBaseUrl/v1/accounts:signInWithPassword?key=$apiKey';
        final signInResponse = await client
            .post(
              Uri.parse(signInUrl),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({
                'email': email,
                'password': password,
                'returnSecureToken': true,
              }),
            )
            .timeout(const Duration(seconds: 5));

        if (signInResponse.statusCode == 200) {
          final data = jsonDecode(signInResponse.body);
          _idToken = data['idToken'];
          return data['localId'];
        }
        throw Exception(
          'Failed to sign in existing test user: ${signInResponse.body}',
        );
      }
      throw Exception('Failed to create test user: ${response.body}');
    }
  }

  /// Generic method to seed a batch of records in Firestore REST API.
  Future<void> seedBatch(List<SeedRecord> records) async {
    final url = '$_firestoreBaseUrl:commit';
    final headers = {
      'Content-Type': 'application/json',
      if (_idToken != null) 'Authorization': 'Bearer $_idToken',
    };

    List<Map<String, dynamic>> writes = [];

    for (var record in records) {
      final docPath =
          'projects/$projectId/databases/(default)/documents/${record.collectionPath}/${record.documentId}';
      writes.add({
        'update': {'name': docPath, 'fields': record.firestoreRestFields},
        'updateMask': {'fieldPaths': record.firestoreRestFields.keys.toList()},
      });
    }

    // Chunk by 400
    for (int i = 0; i < writes.length; i += 400) {
      final end = (i + 400 > writes.length) ? writes.length : i + 400;
      final chunk = writes.sublist(i, end);

      final response = await client
          .post(
            Uri.parse(url),
            headers: headers,
            body: jsonEncode({'writes': chunk}),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) {
        throw Exception('Batch commit failed: ${response.body}');
      }
    }
  }
}
