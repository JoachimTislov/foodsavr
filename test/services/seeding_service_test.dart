import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:foodsavr/mock_data/global_products.dart';
import 'package:foodsavr/services/seeding_service.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test(
    'seedGlobalProducts patches every catalog product into products',
    () async {
      final requests = <http.Request>[];
      final service = SeedingService(
        projectId: 'demo-project',
        host: 'localhost',
        authPort: '9099',
        firestorePort: '8080',
        client: MockClient((request) async {
          requests.add(request);
          return http.Response('{}', 200);
        }),
      );

      await service.seedGlobalProducts();

      final catalog = GlobalProductsData.getProducts();
      expect(requests, hasLength(catalog.length));
      for (final (index, request) in requests.indexed) {
        final data = catalog[index];
        expect(request.method, 'PATCH');
        expect(request.url.pathSegments.sublist(6), ['products', data['id']]);
        expect(request.headers['Authorization'], 'Bearer owner');
        final fields = (jsonDecode(request.body) as Map)['fields'] as Map;
        for (final key in [
          'id',
          'name',
          'description',
          'category',
          'barcode',
        ]) {
          expect(fields[key], {'stringValue': data[key]}, reason: key);
        }
        expect(fields['userId'], {'stringValue': 'global'});
        expect(fields['isGlobal'], {'booleanValue': true});
      }
    },
  );
}
