import 'dart:convert';

import 'package:injectable/injectable.dart';
import 'package:logger/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/product_model.dart';

/// How a purchase was confirmed. [name] is the stored value.
enum PurchaseSource { manual, receipt }

/// The purchases a user made from their shopping lists, newest first, kept on
/// this device.
@lazySingleton
class PurchaseHistoryService {
  static const maxEntries = 50;

  final Logger _logger;

  /// Completes when the latest [record] call has finished.
  Future<void>? _lastWrite;

  PurchaseHistoryService(this._logger);

  static String _key(String userId) => 'purchase_history_$userId';

  Future<List<Map<String, dynamic>>> load(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    return _decode(prefs.getString(_key(userId)));
  }

  /// Adds [products] and returns the saved history. Calls run one at a time,
  /// so overlapping purchases cannot overwrite each other.
  Future<List<Map<String, dynamic>>> record(
    String userId,
    List<Product> products,
    PurchaseSource source,
  ) {
    final result = (_lastWrite ?? Future<void>.value()).then(
      (_) => _append(userId, products, source),
    );
    // A failed write is reported to its caller and never blocks later ones.
    _lastWrite = result.then<void>(
      (_) {},
      onError: (Object error) =>
          _logger.e('Could not record a purchase: ${error.runtimeType}'),
    );
    return result;
  }

  Future<List<Map<String, dynamic>>> _append(
    String userId,
    List<Product> products,
    PurchaseSource source,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final purchasedAt = DateTime.now().toIso8601String();
    final entries = [
      for (final product in products)
        <String, dynamic>{
          'productId': product.id,
          'name': product.name,
          'quantity': product.quantity,
          'source': source.name,
          'purchasedAt': purchasedAt,
        },
      ..._decode(prefs.getString(_key(userId))),
    ].take(maxEntries).toList(growable: false);
    if (!await prefs.setString(_key(userId), jsonEncode(entries))) {
      throw StateError('The purchase history was not saved.');
    }
    return entries;
  }

  List<Map<String, dynamic>> _decode(String? raw) {
    if (raw == null || raw.isEmpty) return const [];
    try {
      return (jsonDecode(raw) as List<dynamic>)
          .whereType<Map<String, dynamic>>()
          .toList(growable: false);
    } catch (error) {
      _logger.w('Discarding unreadable purchase history: ${error.runtimeType}');
      return const [];
    }
  }
}
