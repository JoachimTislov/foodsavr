import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:foodsavr/services/standalone_seeding_service.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  Future<http.Request> commit({required bool isRemote}) async {
    late http.Request sent;
    final service = StandaloneSeedingService(
      projectId: 'demo-project',
      isRemote: isRemote,
      client: MockClient((request) async {
        sent = request;
        return http.Response('{}', 200);
      }),
    );
    await service.seedBatch([
      SeedRecord('products', 'global-a', {
        'barcode': {'stringValue': '4006381333931'},
      }),
    ]);
    return sent;
  }

  test('seedBatch commits the record fields to its collection', () async {
    final request = await commit(isRemote: false);

    final write = ((jsonDecode(request.body) as Map)['writes'] as List).single;
    expect(
      write['update']['name'],
      'projects/demo-project/databases/(default)/documents/products/global-a',
    );
    expect(write['update']['fields']['barcode'], {
      'stringValue': '4006381333931',
    });
    expect(write['updateMask'], {
      'fieldPaths': ['barcode'],
    });
  });

  test('only emulator commits use the rules-bypassing owner token', () async {
    final emulator = await commit(isRemote: false);
    final remote = await commit(isRemote: true);

    expect(emulator.headers['Authorization'], 'Bearer owner');
    expect(remote.headers, isNot(contains('Authorization')));
  });
}
