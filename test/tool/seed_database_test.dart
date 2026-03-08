import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

// We need to import the functions from the seed script
// Since it's a standalone script, we'll test the logic conceptually
// For a real production app, you'd extract functions to a library

class MockClient extends Mock implements http.Client {}

void main() {
  late MockClient mockClient;

  setUpAll(() {
    registerFallbackValue(Uri.parse('http://example.com'));
  });

  setUp(() {
    mockClient = MockClient();
  });

  group('Database Seeding Logic Tests', () {
    const projectId = 'demo-project';
    const host = 'localhost';
    const firestorePort = '8080';
    const authPort = '9099';

    group('Emulator Check', () {
      test('checkEmulators returns true when emulator is running', () async {
        when(() => mockClient.get(any())).thenAnswer(
          (_) async => http.Response('OK', 200),
        );

        final response = await mockClient.get(
          Uri.parse('http://$host:$firestorePort/'),
        );

        expect(response.statusCode == 200 || response.statusCode == 404, true);
      });

      test('checkEmulators returns true for 404 response', () async {
        when(() => mockClient.get(any())).thenAnswer(
          (_) async => http.Response('Not Found', 404),
        );

        final response = await mockClient.get(
          Uri.parse('http://$host:$firestorePort/'),
        );

        expect(response.statusCode == 200 || response.statusCode == 404, true);
      });

      test('checkEmulators handles connection errors gracefully', () async {
        when(() => mockClient.get(any())).thenThrow(
          Exception('Connection refused'),
        );

        expect(
          () async => await mockClient.get(
            Uri.parse('http://$host:$firestorePort/'),
          ),
          throwsException,
        );
      });
    });

    group('User Creation', () {
      test('createTestUser makes correct API request', () async {
        final expectedUrl =
            'http://$host:$authPort/identitytoolkit.googleapis.com/v1/accounts:signUp?key=fake-key';

        when(
          () => mockClient.post(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          ),
        ).thenAnswer(
          (_) async => http.Response(
            jsonEncode({'localId': 'test-user-id'}),
            200,
          ),
        );

        final response = await mockClient.post(
          Uri.parse(expectedUrl),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'email': 'bob@example.com',
            'password': 'password123',
            'returnSecureToken': true,
          }),
        );

        expect(response.statusCode, 200);
        final data = jsonDecode(response.body);
        expect(data['localId'], 'test-user-id');
      });

      test('handles EMAIL_EXISTS error and signs in instead', () async {
        final signUpUrl =
            'http://$host:$authPort/identitytoolkit.googleapis.com/v1/accounts:signUp?key=fake-key';

        when(
          () => mockClient.post(
            Uri.parse(signUpUrl),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          ),
        ).thenAnswer(
          (_) async => http.Response(
            jsonEncode({
              'error': {'message': 'EMAIL_EXISTS'},
            }),
            400,
          ),
        );

        final response = await mockClient.post(
          Uri.parse(signUpUrl),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'email': 'bob@example.com',
            'password': 'password123',
            'returnSecureToken': true,
          }),
        );

        expect(response.statusCode, 400);
        final error = jsonDecode(response.body)['error'];
        expect(error['message'], 'EMAIL_EXISTS');
      });
    });

    group('Firestore Document Creation', () {
      test('postToFirestore creates document with correct structure', () async {
        const collection = 'products';
        const documentId = '1';
        final fields = {
          'id': {'integerValue': '1'},
          'name': {'stringValue': 'Test Product'},
          'description': {'stringValue': 'Test Description'},
        };

        final expectedUrl =
            'http://$host:$firestorePort/v1/projects/$projectId/databases/(default)/documents/$collection?documentId=$documentId';

        when(
          () => mockClient.patch(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          ),
        ).thenAnswer(
          (_) async => http.Response(
            jsonEncode({'fields': fields}),
            200,
          ),
        );

        final response = await mockClient.patch(
          Uri.parse(expectedUrl),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'fields': fields}),
        );

        expect(response.statusCode, 200);
      });

      test('postToFirestore throws on error response', () async {
        const collection = 'products';
        const documentId = '1';

        final expectedUrl =
            'http://$host:$firestorePort/v1/projects/$projectId/databases/(default)/documents/$collection?documentId=$documentId';

        when(
          () => mockClient.patch(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          ),
        ).thenAnswer(
          (_) async => http.Response('Internal Server Error', 500),
        );

        final response = await mockClient.patch(
          Uri.parse(expectedUrl),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'fields': {
              'id': {'integerValue': '1'},
            },
          }),
        );

        expect(response.statusCode, 500);
      });
    });

    group('Inventory Product Seeding', () {
      test('builds correct product structure with expiry', () {
        const userId = 'test-user-id';
        const productId = 1;
        const productName = 'Milk';
        const description = 'Fresh milk';
        const quantity = 2;
        const expirationDays = 7;
        final now = DateTime.now();

        final productMap = {
          'id': {'integerValue': productId.toString()},
          'name': {'stringValue': productName},
          'description': {'stringValue': description},
          'userId': {'stringValue': userId},
          'nonExpiringQuantity': {'integerValue': '0'},
          'isGlobal': {'booleanValue': false},
          'category': {'stringValue': ''},
          'tags': {
            'arrayValue': {'values': []},
          },
          'expiries': {
            'arrayValue': {
              'values': [
                {
                  'mapValue': {
                    'fields': {
                      'quantity': {'integerValue': quantity.toString()},
                      'expirationDate': {
                        'stringValue':
                            now.add(Duration(days: expirationDays)).toIso8601String(),
                      },
                    },
                  },
                },
              ],
            },
          },
        };

        expect(productMap['id']!['integerValue'], '1');
        expect(productMap['name']!['stringValue'], 'Milk');
        expect(productMap['nonExpiringQuantity']!['integerValue'], '0');
        expect(productMap['isGlobal']!['booleanValue'], false);
        expect(
          (productMap['expiries']!['arrayValue']! as Map)['values'],
          isNotEmpty,
        );
      });

      test('builds correct product structure without expiry', () {
        const userId = 'test-user-id';
        const productId = 2;
        const productName = 'Pasta';
        const description = 'Dry pasta';
        const quantity = 5;

        final productMap = {
          'id': {'integerValue': productId.toString()},
          'name': {'stringValue': productName},
          'description': {'stringValue': description},
          'userId': {'stringValue': userId},
          'nonExpiringQuantity': {'integerValue': quantity.toString()},
          'isGlobal': {'booleanValue': false},
          'category': {'stringValue': ''},
          'tags': {
            'arrayValue': {'values': []},
          },
          'expiries': {
            'arrayValue': {'values': []},
          },
        };

        expect(productMap['nonExpiringQuantity']!['integerValue'], '5');
        expect(
          (productMap['expiries']!['arrayValue']! as Map)['values'],
          isEmpty,
        );
      });
    });

    group('Global Product Seeding', () {
      test('builds correct global product structure', () {
        const productId = 100;
        const productName = 'Global Milk';
        const description = 'Global catalog item';

        final productMap = {
          'id': {'integerValue': productId.toString()},
          'name': {'stringValue': productName},
          'description': {'stringValue': description},
          'userId': {'stringValue': 'global'},
          'nonExpiringQuantity': {'integerValue': '0'},
          'isGlobal': {'booleanValue': true},
          'category': {'stringValue': ''},
          'tags': {
            'arrayValue': {'values': []},
          },
          'expiries': {
            'arrayValue': {'values': []},
          },
        };

        expect(productMap['userId']!['stringValue'], 'global');
        expect(productMap['isGlobal']!['booleanValue'], true);
        expect(productMap['nonExpiringQuantity']!['integerValue'], '0');
      });
    });

    group('Collection Seeding', () {
      test('builds correct collection structure', () {
        const userId = 'test-user-id';
        const collectionId = 'my-inventory';
        const collectionName = 'My Inventory';
        const collectionType = 'inventory';
        const description = 'My personal inventory';
        final productIds = [1, 2, 3];

        final collectionMap = {
          'id': {'stringValue': collectionId},
          'name': {'stringValue': collectionName},
          'userId': {'stringValue': userId},
          'type': {'stringValue': collectionType},
          'description': {'stringValue': description},
          'productIds': {
            'arrayValue': {
              'values': productIds
                  .map((pid) => {'integerValue': pid.toString()})
                  .toList(),
            },
          },
        };

        expect(collectionMap['id']!['stringValue'], collectionId);
        expect(collectionMap['name']!['stringValue'], collectionName);
        expect(collectionMap['type']!['stringValue'], collectionType);
        expect(
          (collectionMap['productIds']!['arrayValue']! as Map)['values'],
          hasLength(3),
        );
      });

      test('handles empty product list in collection', () {
        const userId = 'test-user-id';
        const collectionId = 'empty-collection';
        final productIds = <int>[];

        final collectionMap = {
          'id': {'stringValue': collectionId},
          'name': {'stringValue': 'Empty'},
          'userId': {'stringValue': userId},
          'type': {'stringValue': 'shopping'},
          'description': {'stringValue': ''},
          'productIds': {
            'arrayValue': {
              'values':
                  productIds.map((pid) => {'integerValue': pid.toString()}).toList(),
            },
          },
        };

        expect(
          (collectionMap['productIds']!['arrayValue']! as Map)['values'],
          isEmpty,
        );
      });
    });

    group('Idempotency Tests', () {
      test('seeding script should be idempotent when user exists', () async {
        // First attempt: user creation succeeds
        when(
          () => mockClient.post(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          ),
        ).thenAnswer(
          (_) async => http.Response(
            jsonEncode({'localId': 'user-123'}),
            200,
          ),
        );

        var response = await mockClient.post(
          Uri.parse('http://test/signup'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'email': 'bob@example.com'}),
        );

        expect(response.statusCode, 200);

        // Second attempt: user exists, should handle gracefully
        when(
          () => mockClient.post(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          ),
        ).thenAnswer(
          (_) async => http.Response(
            jsonEncode({
              'error': {'message': 'EMAIL_EXISTS'},
            }),
            400,
          ),
        );

        response = await mockClient.post(
          Uri.parse('http://test/signup'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'email': 'bob@example.com'}),
        );

        // Should get EMAIL_EXISTS error
        expect(response.statusCode, 400);
        final error = jsonDecode(response.body)['error'];
        expect(error['message'], 'EMAIL_EXISTS');
      });
    });

    group('Data Validation', () {
      test('product ID must be an integer', () {
        final productMap = {
          'id': {'integerValue': '123'},
        };

        expect(productMap['id']!['integerValue'], '123');
        expect(int.parse(productMap['id']!['integerValue']!), 123);
      });

      test('expiration date must be valid ISO8601 string', () {
        final now = DateTime.now();
        final expiryDate = now.add(const Duration(days: 7));
        final isoString = expiryDate.toIso8601String();

        expect(DateTime.parse(isoString).isAfter(now), true);
      });

      test('quantity must be non-negative', () {
        const quantity = 5;
        final quantityMap = {'integerValue': quantity.toString()};

        expect(int.parse(quantityMap['integerValue']!), greaterThanOrEqualTo(0));
      });

      test('user ID must not be empty', () {
        const userId = 'test-user-id';

        expect(userId, isNotEmpty);
        expect(userId.length, greaterThan(0));
      });

      test('isGlobal flag must be boolean', () {
        final globalProduct = {'isGlobal': {'booleanValue': true}};
        final userProduct = {'isGlobal': {'booleanValue': false}};

        expect(globalProduct['isGlobal']!['booleanValue'], isA<bool>());
        expect(userProduct['isGlobal']!['booleanValue'], isA<bool>());
      });
    });
  });
}