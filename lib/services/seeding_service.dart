import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:injectable/injectable.dart';

import '../mock_data/collections.dart';
import '../mock_data/global_products.dart';
import '../mock_data/inventory_products.dart';
import '../models/collection_model.dart';
import '../models/product_model.dart';
import '../utils/collection_types.dart';
import '../utils/config.dart';

/// Service to handle database seeding for the Firebase Emulator via REST API.
@lazySingleton
class SeedingService {
  final String projectId;
  final String host;
  final String authPort;
  final String firestorePort;
  final http.Client client;

  SeedingService({
    required this.projectId,
    required this.host,
    required this.authPort,
    required this.firestorePort,
    http.Client? client,
  }) : client = client ?? http.Client();

  @factoryMethod
  static SeedingService create() {
    return SeedingService(
      projectId: 'demo-project',
      host: Config.emulatorHost,
      authPort: '9099',
      firestorePort: '8080',
    );
  }

  /// Checks if the Firebase Emulators are running.
  // TODO: Same check as in main.dart
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

  /// Creates a test user or signs in if already exists.
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

  /// Seeds admin role in a centralized document (roles/admins).
  Future<void> seedUserDocument(String userId) async {
    final url =
        'http://$host:$firestorePort/v1/projects/$projectId/databases/(default)/documents/roles/admins?updateMask.fieldPaths=$userId';
    final response = await client
        .patch(
          Uri.parse(url),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'fields': {
              userId: {'booleanValue': true},
            },
          }),
        )
        .timeout(const Duration(seconds: 5));

    if (response.statusCode != 200) {
      throw Exception('Failed to seed admin role: ${response.body}');
    }
  }

  /// Seeds inventory products for a specific user.
  Future<List<int>> seedInventoryProducts(String userId) async {
    final productsData = InventoryProductsData.getProducts();
    final addedIds = <int>[];
    final now = DateTime.now();

    for (var data in productsData) {
      final id = data['id'] as int;
      final expirationDays = data['expirationDays'] as int?;
      final quantity = data['quantity'] as int? ?? 1;

      final product = Product(
        id: id,
        name: data['name'] as String,
        description: data['description'] as String,
        userId: userId,
        nonExpiringQuantity: expirationDays == null ? quantity : 0,
        expiries: expirationDays != null
            ? [
                ExpiryEntry(
                  quantity: quantity,
                  expirationDate: now.add(Duration(days: expirationDays)),
                ),
              ]
            : [],
        category: data['category'] as String?,
      );

      await postToFirestore(
        'products',
        id.toString(),
        product.toFirestoreRest(),
      );
      addedIds.add(id);
    }
    return addedIds;
  }

  /// Seeds global products catalog.
  Future<void> seedGlobalProducts() async {
    final productsData = GlobalProductsData.getProducts();

    for (var data in productsData) {
      final id = data['id'] as int;
      final product = Product(
        id: id,
        name: data['name'] as String,
        description: data['description'] as String,
        userId: 'global',
        isGlobal: true,
        category: data['category'] as String?,
      );

      await postToFirestore(
        'products',
        id.toString(),
        product.toFirestoreRest(),
      );
    }
  }

  /// Seeds collections for a specific user.
  Future<void> seedCollections(String userId) async {
    final collectionsData = CollectionsData.getCollections();

    for (var data in collectionsData) {
      final id = data['id'] as String;
      final mockProductIds = List<int>.from(data['productIds'] as List);

      final collection = Collection(
        id: id,
        name: data['name'] as String,
        productIds: mockProductIds,
        userId: userId,
        description: data['description'] as String?,
        type: CollectionType.values.firstWhere(
          (e) => e.name == data['type'],
          orElse: () => CollectionType.inventory,
        ),
      );

      await postToFirestore('collections', id, collection.toFirestoreRest());
    }
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
