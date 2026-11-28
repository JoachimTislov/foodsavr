import 'dart:io';

import 'package:foodsavr/services/open_food_facts_client.dart';
import 'package:logger/logger.dart';
import 'package:openfoodfacts/openfoodfacts.dart' as off;

/// A real [OpenFoodFactsClient] over a scripted catalog.
class FakeOpenFoodFacts {
  /// Product names by barcode, as an exact lookup finds them.
  final Map<String, String> known = {};

  /// Product names every search returns.
  List<String> searchable = [];
  List<String> tags = [];
  bool offline = false;

  final List<String> lookups = [];
  final List<String> searches = [];

  late final OpenFoodFactsClient client = OpenFoodFactsClient.withFetch(
    Logger(level: Level.off),
    (configuration) async {
      _checkConnection();
      lookups.add(configuration.barcode);
      final name = known[configuration.barcode];
      if (name == null) return off.ProductResultV3()..status = 'failure';
      return off.ProductResultV3()
        ..status = off.ProductResultV3.statusSuccess
        ..product = (off.Product()
          ..productName = name
          ..categoriesTags = tags);
    },
    search: (configuration) async {
      _checkConnection();
      searches.add(configuration.getParametersMap()['search_terms']!);
      return off.SearchResult(
        products: [
          for (final (index, name) in searchable.indexed)
            off.Product(
              barcode: '704000000000$index',
              productName: name,
              brands: 'Brand $index',
            )..categoriesTags = tags,
        ],
      );
    },
  );

  void _checkConnection() {
    if (offline) throw const SocketException('offline');
  }
}
