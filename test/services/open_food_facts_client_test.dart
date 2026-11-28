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

  group('searchProducts', () {
    OpenFoodFactsClient searching(
      OffSearchFetch search, {
      Duration timeout = OpenFoodFactsClient.defaultTimeout,
    }) => OpenFoodFactsClient.withFetch(
      Logger(level: Level.off),
      (_) async => throw StateError('not a barcode lookup'),
      search: search,
      timeout: timeout,
    );

    test('returns several named candidates with brand and barcode', () async {
      off.ProductSearchQueryConfiguration? sent;
      final client = searching((configuration) async {
        sent = configuration;
        return off.SearchResult(
          products: [
            off.Product(
              barcode: '7038010009457',
              productName: 'Lettmelk',
              brands: 'Tine',
            )..categoriesTags = ['en:dairies'],
            off.Product(barcode: '96385074', productName: 'Helmelk'),
            off.Product(barcode: '4006381333931', productName: ' '),
          ],
        );
      });

      final result = await client.searchProducts(' melk ', pageSize: 5);

      final products = (result as OffSearchFound).products;
      expect(products.map((p) => p.name), ['Lettmelk', 'Helmelk']);
      expect(products.first.brand, 'Tine');
      expect(products.first.barcode, '7038010009457');
      expect(products.first.tags, ['en:dairies']);
      expect(products.last.brand, isNull);
      final parameters = sent!.getParametersMap();
      expect(parameters['search_terms'], 'melk');
      expect(parameters['page_size'], '5');
    });

    test('no match, and a blank query, are empty', () async {
      var calls = 0;
      final client = searching((_) async {
        calls++;
        return off.SearchResult(products: []);
      });

      expect(await client.searchProducts('zzz'), isA<OffSearchEmpty>());
      expect(await client.searchProducts('  '), isA<OffSearchEmpty>());
      expect(calls, 1);
    });

    for (final (name, error) in [
      ('SocketException', const SocketException('Failed host lookup')),
      ('ClientException', http.ClientException('XMLHttpRequest error')),
      ('rate limit', const off.TooManyRequestsException()),
    ]) {
      test('$name is offline', () async {
        final client = searching((_) async => throw error);
        expect(await client.searchProducts('melk'), isA<OffSearchOffline>());
      });
    }

    test('a timeout is offline', () async {
      final never = Completer<off.SearchResult>();
      final client = searching(
        (_) => never.future,
        timeout: const Duration(milliseconds: 10),
      );

      expect(await client.searchProducts('melk'), isA<OffSearchOffline>());
    });
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
