import 'dart:async';
import 'dart:io' show IOException;

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:injectable/injectable.dart';
import 'package:logger/logger.dart';
import 'package:openfoodfacts/openfoodfacts.dart' as off;

/// Product data that Open Food Facts returned for a barcode.
class OffProductData {
  final String? name;
  final String? brand;
  final String? barcode;
  final String? imageUrl;
  final List<String> tags;

  const OffProductData({
    this.name,
    this.brand,
    this.barcode,
    this.imageUrl,
    this.tags = const [],
  });
}

/// Outcome of an Open Food Facts barcode lookup.
sealed class OffLookup {
  const OffLookup();
}

final class OffFound extends OffLookup {
  final OffProductData product;
  const OffFound(this.product);
}

/// Open Food Facts answered and does not know the barcode.
final class OffNotFound extends OffLookup {
  const OffNotFound();
}

/// The lookup did not reach Open Food Facts (no connection or timeout).
final class OffOffline extends OffLookup {
  const OffOffline();
}

/// Outcome of an Open Food Facts search.
sealed class OffSearchResult {
  const OffSearchResult();
}

final class OffSearchFound extends OffSearchResult {
  /// At least one product, each with a name.
  final List<OffProductData> products;
  const OffSearchFound(this.products);
}

final class OffSearchEmpty extends OffSearchResult {
  const OffSearchEmpty();
}

/// Open Food Facts gave no answer: no connection, a timeout, or the service
/// refused the request.
final class OffSearchOffline extends OffSearchResult {
  const OffSearchOffline();
}

typedef OffFetch =
    Future<off.ProductResultV3> Function(
      off.ProductQueryConfiguration configuration,
    );

typedef OffSearchFetch =
    Future<off.SearchResult> Function(
      off.ProductSearchQueryConfiguration configuration,
    );

/// Barcode lookups and searches against Open Food Facts with a timeout and an
/// honest offline result.
@lazySingleton
class OpenFoodFactsClient {
  static const defaultTimeout = Duration(seconds: 8);

  final Logger _logger;
  final OffFetch _fetch;
  final OffSearchFetch _search;
  final Duration _timeout;

  OpenFoodFactsClient(this._logger)
    : _fetch = off.OpenFoodAPIClient.getProductV3,
      _search = _searchOpenFoodFacts,
      _timeout = defaultTimeout;

  @visibleForTesting
  OpenFoodFactsClient.withFetch(
    this._logger,
    this._fetch, {
    OffSearchFetch search = _searchOpenFoodFacts,
    Duration timeout = defaultTimeout,
  }) : _search = search,
       _timeout = timeout;

  static Future<off.SearchResult> _searchOpenFoodFacts(
    off.ProductSearchQueryConfiguration configuration,
  ) => off.OpenFoodAPIClient.searchProducts(null, configuration);

  static const _fields = [
    off.ProductField.BARCODE,
    off.ProductField.NAME,
    off.ProductField.BRANDS,
    off.ProductField.IMAGE_FRONT_URL,
    off.ProductField.LABELS_TAGS,
    off.ProductField.CATEGORIES_TAGS,
  ];

  Future<OffLookup> lookup(String barcode, {String languageCode = 'nb'}) async {
    final configuration = off.ProductQueryConfiguration(
      barcode,
      language: _language(languageCode),
      version: off.ProductQueryVersion.latestVersion,
      fields: _fields,
    );
    try {
      final result = await _fetch(configuration).timeout(_timeout);
      final product = result.product;
      if (result.status != off.ProductResultV3.statusSuccess ||
          product == null) {
        return const OffNotFound();
      }
      return OffFound(_data(product, barcode: barcode));
    } catch (e) {
      if (isOfflineError(e)) {
        _logger.w('Open Food Facts unreachable: ${e.runtimeType}');
        return const OffOffline();
      }
      _logger.e('Open Food Facts lookup failed: ${e.runtimeType}');
      return const OffNotFound();
    }
  }

  /// Products matching [query], a name, brand or barcode, best match first.
  Future<OffSearchResult> searchProducts(
    String query, {
    String languageCode = 'nb',
    int pageSize = 8,
  }) async {
    final terms = query.trim();
    if (terms.isEmpty) return const OffSearchEmpty();
    final configuration = off.ProductSearchQueryConfiguration(
      parametersList: [
        off.SearchTerms(terms: [terms]),
        off.PageSize(size: pageSize),
      ],
      language: _language(languageCode),
      version: off.ProductQueryVersion.latestVersion,
      fields: _fields,
    );
    try {
      final result = await _search(configuration).timeout(_timeout);
      // A candidate without a name cannot be told apart.
      final products = [
        for (final product in result.products ?? const <off.Product>[])
          if (product.productName?.trim().isNotEmpty ?? false) _data(product),
      ].take(pageSize).toList();
      return products.isEmpty
          ? const OffSearchEmpty()
          : OffSearchFound(products);
    } catch (e) {
      if (isOfflineError(e) ||
          e is off.TooManyRequestsException ||
          e is off.HttpStatusException) {
        _logger.w('Open Food Facts search unavailable: ${e.runtimeType}');
        return const OffSearchOffline();
      }
      _logger.e('Open Food Facts search failed: ${e.runtimeType}');
      return const OffSearchEmpty();
    }
  }

  static OffProductData _data(off.Product product, {String? barcode}) =>
      OffProductData(
        name: product.productName,
        brand: _blankToNull(product.brands),
        barcode: barcode ?? _blankToNull(product.barcode),
        imageUrl: product.imageFrontUrl,
        // Labels and categories together give better shelf-life heuristics.
        tags: [...?product.labelsTags, ...?product.categoriesTags],
      );

  static String? _blankToNull(String? value) =>
      value == null || value.trim().isEmpty ? null : value.trim();

  /// Whether [error] means the request never reached the server. Covers
  /// `SocketException` and other I/O failures, timeouts, and the HTTP
  /// client's connection errors (the only kind raised on web).
  static bool isOfflineError(Object error) =>
      error is TimeoutException ||
      error is IOException ||
      error is http.ClientException;

  static off.OpenFoodFactsLanguage _language(String languageCode) =>
      switch (languageCode) {
        'nb' || 'no' => off.OpenFoodFactsLanguage.NORWEGIAN,
        _ => off.OpenFoodFactsLanguage.ENGLISH,
      };
}
