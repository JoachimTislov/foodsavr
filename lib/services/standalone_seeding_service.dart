import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/product_model.dart';
import '../models/collection_model.dart';
import 'base_seeding_service.dart';

/// Service to handle database seeding for the Firebase Emulator via REST API.
class StandaloneSeedingService extends BaseSeedingService {
  final String projectId;
  final String host;
  final String authPort;
  final String firestorePort;
  final http.Client client;

  StandaloneSeedingService({
    required this.projectId,
    required this.host,
    required this.authPort,
    required this.firestorePort,
    http.Client? client,
  }) : client = client ?? http.Client();

  /// Checks if the Firebase Emulators are running.
  Future<bool> checkEmulators() async {
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

  @override
  Future<String> createTestUser(String email, String password) async {
    final url =
        'http://$host:$authPort/identitytoolkit.googleapis.com/v1/accounts:signUp?key=fake-key';
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
      return data['localId'];
    } else {
      final error = jsonDecode(response.body)['error'];
      if (error != null && error['message'] == 'EMAIL_EXISTS') {
        final signInUrl =
            'http://$host:$authPort/identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=fake-key';
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
          return data['localId'];
        }
        throw Exception(
          'Failed to sign in existing test user: ${signInResponse.body}',
        );
      }
      throw Exception('Failed to create test user: ${response.body}');
    }
  }

  @override
  Future<void> addProduct(Product product) async {
    await postToFirestore(
      'products',
      product.id.toString(),
      product.toFirestoreRest(),
    );
  }

  @override
  Future<void> addCollection(Collection collection) async {
    await postToFirestore(
      'collections',
      collection.id,
      collection.toFirestoreRest(),
    );
  }

  /// Generic method to patch a document in Firestore REST API.
  Future<void> postToFirestore(
    String collection,
    String documentId,
    Map<String, dynamic> fields,
  ) async {
    final url =
        'http://$host:$firestorePort/v1/projects/$projectId/databases/(default)/documents/$collection/$documentId';
    final response = await client
        .patch(
          Uri.parse(url),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'fields': fields}),
        )
        .timeout(const Duration(seconds: 5));

    if (response.statusCode != 200) {
      throw Exception(
        'Failed to seed document $documentId in $collection: ${response.body}',
      );
    }
  }
}
