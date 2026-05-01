import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';
import 'package:foodsavr/services/seeding_service.dart';
import 'package:foodsavr/models/product_model.dart';

class MockClient extends Mock implements http.Client {}

void main() {
  late MockClient mockClient;
  late SeedingService seedingService;

  const projectId = 'demo-project';
  const host = 'localhost';
  const firestorePort = '8080';
  const authPort = '9099';

  setUpAll(() {
    registerFallbackValue(Uri.parse('http://example.com'));
  });

  setUp(() {
    mockClient = MockClient();
    seedingService = SeedingService(
      projectId: projectId,
      host: host,
      authPort: authPort,
      firestorePort: firestorePort,
      client: mockClient,
    );
  });

  group('SeedingService Tests', () {
    group('Emulator Check', () {
      test('checkEmulators returns true when emulator is running', () async {
        when(
          () => mockClient.get(any()),
        ).thenAnswer((_) async => http.Response('OK', 200));

        final result = await seedingService.checkEmulators();
        expect(result, isTrue);
      });

      test('checkEmulators returns false on connection error', () async {
        when(
          () => mockClient.get(any()),
        ).thenThrow(Exception('Connection refused'));

        final result = await seedingService.checkEmulators();
        expect(result, isFalse);
      });
    });

    group('User Creation/Sign-in', () {
      const email = 'test@example.com';
      const password = 'password123';

      test('createTestUser succeeds on new user creation', () async {
        when(
          () => mockClient.post(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          ),
        ).thenAnswer(
          (_) async =>
              http.Response(jsonEncode({'localId': 'new-user-id'}), 200),
        );

        final userId = await seedingService.createTestUser(email, password);
        expect(userId, 'new-user-id');
      });

      test('createTestUser signs in if email already exists', () async {
        // First mock: signUp fails with EMAIL_EXISTS
        when(
          () => mockClient.post(
            Uri.parse(
              'http://$host:$authPort/identitytoolkit.googleapis.com/v1/accounts:signUp?key=fake-key',
            ),
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

        // Second mock: signIn succeeds
        when(
          () => mockClient.post(
            Uri.parse(
              'http://$host:$authPort/identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=fake-key',
            ),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          ),
        ).thenAnswer(
          (_) async =>
              http.Response(jsonEncode({'localId': 'existing-user-id'}), 200),
        );

        final userId = await seedingService.createTestUser(email, password);
        expect(userId, 'existing-user-id');
      });

      test('createTestUser throws on unexpected sign-up error', () async {
        when(
          () => mockClient.post(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          ),
        ).thenAnswer(
          (_) async => http.Response(
            jsonEncode({
              'error': {'message': 'INVALID_EMAIL'},
            }),
            400,
          ),
        );

        expect(
          () => seedingService.createTestUser(email, password),
          throwsException,
        );
      });
    });

    group('Firestore Operations', () {
      test(
        'seedUserDocument sends correct PATCH request to roles/admins',
        () async {
          when(
            () => mockClient.patch(
              any(),
              headers: any(named: 'headers'),
              body: any(named: 'body'),
            ),
          ).thenAnswer((_) async => http.Response('OK', 200));

          await seedingService.seedUserDocument('admin-user-id');

          verify(
            () => mockClient.patch(
              Uri.parse(
                'http://$host:$firestorePort/v1/projects/$projectId/databases/(default)/documents/roles/admins?updateMask.fieldPaths=%60admin-user-id%60',
              ),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({
                'fields': {
                  'admin-user-id': {'booleanValue': true},
                },
              }),
            ),
          ).called(1);
        },
      );

      test('postToFirestore sends correct PATCH request', () async {
        final fields = {
          'name': {'stringValue': 'Test'},
        };
        final collection = 'test_col';
        final docId = 'doc_123';

        when(
          () => mockClient.patch(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          ),
        ).thenAnswer((_) async => http.Response('OK', 200));

        await seedingService.postToFirestore(collection, docId, fields);

        verify(
          () => mockClient.patch(
            Uri.parse(
              'http://$host:$firestorePort/v1/projects/$projectId/databases/(default)/documents/$collection/$docId',
            ),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'fields': fields}),
          ),
        ).called(1);
      });

      test('postToFirestore throws on failure', () async {
        when(
          () => mockClient.patch(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          ),
        ).thenAnswer((_) async => http.Response('Error', 500));

        expect(
          () => seedingService.postToFirestore('col', 'id', {}),
          throwsException,
        );
      });
    });

    group('Model Serialization (toFirestoreRest)', () {
      test('Product toFirestoreRest matches expected Firestore REST shape', () {
        final now = DateTime.now();
        final product = Product(
          id: 123,
          name: 'Milk',
          description: 'Dairy',
          userId: 'user_1',
          expiries: [ExpiryEntry(quantity: 2, expirationDate: now)],
          nonExpiringQuantity: 1,
          category: 'Drinks',
          isGlobal: false,
          tags: ['fresh', 'local'],
        );

        final rest = product.toFirestoreRest();

        expect(rest['id']['integerValue'], '123');
        expect(rest['name']['stringValue'], 'Milk');
        expect(rest['description']['stringValue'], 'Dairy');
        expect(rest['userId']['stringValue'], 'user_1');
        expect(rest['nonExpiringQuantity']['integerValue'], '1');
        expect(rest['category']['stringValue'], 'Drinks');
        expect(rest['isGlobal']['booleanValue'], isFalse);

        final expiries = rest['expiries']['arrayValue']['values'] as List;
        expect(expiries, hasLength(1));
        final entry = expiries[0]['mapValue']['fields'];
        expect(entry['quantity']['integerValue'], '2');
        expect(entry['expirationDate']['stringValue'], now.toIso8601String());

        final tags = rest['tags']['arrayValue']['values'] as List;
        expect(tags, hasLength(2));
        expect(tags[0]['stringValue'], 'fresh');
      });

      test('Product toFirestoreRest handles null/empty fields', () {
        final product = Product(
          id: 456,
          name: 'Water',
          description: '',
          userId: 'user_2',
        );

        final rest = product.toFirestoreRest();
        expect(rest['category']['stringValue'], '');
        expect(rest['barcode']['stringValue'], '');
        expect(rest['expiries']['arrayValue']['values'], isEmpty);
      });
    });

    group('Edge Case Validations', () {
      test('Product with negative quantity (sanitization/logic check)', () {
        // Even if we pass negative, the model currently just serializes it.
        // We might want to add validation in the model later,
        // but for now we test that it serializes correctly.
        final product = Product(
          id: 1,
          name: 'Test',
          description: '',
          userId: 'u1',
          nonExpiringQuantity: -5,
        );

        final rest = product.toFirestoreRest();
        expect(rest['nonExpiringQuantity']['integerValue'], '-5');
      });

      test('ExpiryEntry with past date is allowed in serialization', () {
        final pastDate = DateTime.now().subtract(const Duration(days: 10));
        final entry = ExpiryEntry(quantity: 1, expirationDate: pastDate);

        final rest = entry.toFirestoreRest();
        expect(
          rest['mapValue']['fields']['expirationDate']['stringValue'],
          pastDate.toIso8601String(),
        );
      });
    });
  });
}
