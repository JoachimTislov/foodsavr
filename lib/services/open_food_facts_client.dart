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
  final String? imageUrl;
  final List<String> tags;

  const OffProductData({this.name, this.imageUrl, this.tags = const []});
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

typedef OffFetch =
    Future<off.ProductResultV3> Function(
      off.ProductQueryConfiguration configuration,
    );

/// Barcode lookups against Open Food Facts with a timeout and an honest
/// offline result.
@lazySingleton
class OpenFoodFactsClient {
  static const defaultTimeout = Duration(seconds: 8);

  final Logger _logger;
  final OffFetch _fetch;
  final Duration _timeout;

  OpenFoodFactsClient(this._logger)
    : _fetch = off.OpenFoodAPIClient.getProductV3,
      _timeout = defaultTimeout;

  @visibleForTesting
  OpenFoodFactsClient.withFetch(
    this._logger,
    this._fetch, {
    Duration timeout = defaultTimeout,
  }) : _timeout = timeout;

  Future<OffLookup> lookup(String barcode, {String languageCode = 'nb'}) async {
    final configuration = off.ProductQueryConfiguration(
      barcode,
      language: _language(languageCode),
      version: off.ProductQueryVersion.latestVersion,
      fields: [
        off.ProductField.NAME,
        off.ProductField.IMAGE_FRONT_URL,
        off.ProductField.LABELS_TAGS,
        off.ProductField.CATEGORIES_TAGS,
      ],
    );
    try {
      final result = await _fetch(configuration).timeout(_timeout);
      final product = result.product;
      if (result.status != off.ProductResultV3.statusSuccess ||
          product == null) {
        return const OffNotFound();
      }
      return OffFound(
        OffProductData(
          name: product.productName,
          imageUrl: product.imageFrontUrl,
          // Labels and categories together give better shelf-life heuristics.
          tags: [...?product.labelsTags, ...?product.categoriesTags],
        ),
      );
    } catch (e) {
      if (isOfflineError(e)) {
        _logger.w('Open Food Facts unreachable: ${e.runtimeType}');
        return const OffOffline();
      }
      _logger.e('Open Food Facts lookup failed: ${e.runtimeType}');
      return const OffNotFound();
    }
  }

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
