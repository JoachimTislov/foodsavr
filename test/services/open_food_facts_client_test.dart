import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:foodsavr/services/open_food_facts_client.dart';
import 'package:http/http.dart' as http;
import 'package:logger/logger.dart';
import 'package:openfoodfacts/openfoodfacts.dart' as off;

OpenFoodFactsClient _client(
  OffFetch fetch, {
  Duration timeout = OpenFoodFactsClient.defaultTimeout,
}) => OpenFoodFactsClient.withFetch(
  Logger(level: Level.off),
  fetch,
  timeout: timeout,
);

void main() {
  test('a timeout is offline, not notFound', () async {
    final never = Completer<off.ProductResultV3>();
    final client = _client(
      (_) => never.future,
      timeout: const Duration(milliseconds: 10),
    );

    expect(await client.lookup('123'), isA<OffOffline>());
  });

  for (final (name, error) in [
    ('SocketException', const SocketException('Failed host lookup')),
    ('ClientException', http.ClientException('XMLHttpRequest error')),
    ('TimeoutException', TimeoutException('slow')),
  ]) {
    test('$name is offline', () async {
      final client = _client((_) async => throw error);
      expect(await client.lookup('123'), isA<OffOffline>());
    });
  }

  test('an unknown barcode is notFound', () async {
    final client = _client(
      (_) async => off.ProductResultV3()..status = 'failure',
    );
    expect(await client.lookup('123'), isA<OffNotFound>());
  });

  test('an unexpected error is notFound', () async {
    final client = _client((_) async => throw const FormatException('bad'));
    expect(await client.lookup('123'), isA<OffNotFound>());
  });

  test('a known barcode returns its name, image and tags', () async {
    final client = _client(
      (_) async => off.ProductResultV3()
        ..status = off.ProductResultV3.statusSuccess
        ..product = (off.Product()
          ..productName = 'Milk'
          ..imageFrontUrl = 'https://example.com/milk.png'
          ..labelsTags = ['en:organic']
          ..categoriesTags = ['en:dairies']),
    );

    final lookup = await client.lookup('123');

    expect(lookup, isA<OffFound>());
    final data = (lookup as OffFound).product;
    expect(data.name, 'Milk');
    expect(data.imageUrl, 'https://example.com/milk.png');
    expect(data.tags, ['en:organic', 'en:dairies']);
  });
}
