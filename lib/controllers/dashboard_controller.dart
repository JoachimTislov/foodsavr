import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:injectable/injectable.dart';
import 'package:logger/logger.dart';

import '../interfaces/i_auth_service.dart';
import '../interfaces/i_receipt_repository.dart';
import '../models/collection_model.dart';
import '../models/dashboard_insights.dart';
import '../models/product_model.dart';
import '../models/receipt_record.dart';
import '../services/collection_service.dart';
import '../services/product_service.dart';
import '../utils/collection_types.dart';
import 'preferences_controller.dart';

/// Holds the dashboard state and the logic to load it, keeping the view free
/// of service logic and manual setState calls. The view rebuilds reactively
/// via watch_it when this notifier changes.
@lazySingleton
class DashboardController extends ChangeNotifier {
  final IAuthService _authService;
  final ProductService _productService;
  final CollectionService _collectionService;
  final PreferencesController _preferences;
  final IReceiptRepository _receipts;
  final Logger _logger;

  DashboardController(
    this._authService,
    this._productService,
    this._collectionService,
    this._preferences,
    this._receipts,
    this._logger,
  ) {
    _preferences.addListener(_onPreferencesChanged);
  }

  List<Product> _expired = const [];
  List<Product> _expiringSoon = const [];
  List<Collection> _inventories = const [];
  List<Collection> _shoppingLists = const [];
  Map<String, int> _productCounts = const {};
  DashboardInsights _insights = const DashboardInsights();
  bool _isEmptyAccount = false;
  int _loadGeneration = 0;
  int? _loadedExpiringSoonDays;

  /// Products with an expired quantity, oldest first.
  List<Product> get expired => _expired;
  List<Product> get expiringSoon => _expiringSoon;
  List<Collection> get inventories => _inventories;
  List<Collection> get shoppingLists => _shoppingLists;

  /// Product count per collection ID. Empty when the counts could not be
  /// resolved.
  Map<String, int> get productCounts => _productCounts;

  /// The counts behind the insight tiles.
  DashboardInsights get insights => _insights;

  /// Whether the user has no inventory, shopping list or product yet.
  bool get isEmptyAccount => _isEmptyAccount;

  /// Loads the dashboard data for the current user and notifies listeners.
  /// Completes normally when there is no signed-in user (state is cleared).
  /// Stale loads are discarded: if the signed-in user changes (or signs out)
  /// while a load is pending, the older results are never published.
  Future<void> load() async {
    final generation = ++_loadGeneration;
    final expiringSoonDays = _preferences.expiringSoonDays;
    _loadedExpiringSoonDays = expiringSoonDays;
    final userId = _authService.getUserId();
    if (userId == null) {
      _expired = const [];
      _expiringSoon = const [];
      _inventories = const [];
      _shoppingLists = const [];
      _productCounts = const {};
      _insights = const DashboardInsights();
      _isEmptyAccount = false;
      notifyListeners();
      return;
    }

    final results = await Future.wait([
      _productService.getExpired(userId),
      _productService.getExpiringSoon(
        userId,
        expiringSoonDays: expiringSoonDays,
      ),
      _collectionService.getCollectionsForUser(userId),
    ]);

    if (generation != _loadGeneration) return;

    final collections = results[2] as List<Collection>;
    // Served from the cache the product lists above just filled.
    final products = await _productService.getProducts(userId);
    final productCounts = await _resolveCounts(userId, collections);
    final receipts = await _loadReceipts(userId);

    if (generation != _loadGeneration) return;

    _expired = results[0] as List<Product>;
    _expiringSoon = results[1] as List<Product>;
    _inventories = _ofType(collections, CollectionType.inventory);
    _shoppingLists = _ofType(collections, CollectionType.shoppingList);
    _productCounts = productCounts;
    _insights = _buildInsights(products, receipts);
    _isEmptyAccount = collections.isEmpty && products.isEmpty;
    notifyListeners();
  }

  DashboardInsights _buildInsights(
    List<Product> products,
    List<ReceiptRecord> receipts,
  ) {
    final since = DateTime.now().subtract(
      const Duration(days: DashboardInsights.recentReceiptDays),
    );
    return DashboardInsights(
      productCount: products.length,
      expiringSoonCount: _expiringSoon.length,
      expiredCount: _expired.length,
      hasExpiries: products.any((product) => product.expiries.isNotEmpty),
      shoppingListCount: _shoppingLists.length,
      shoppingListItemCount: [
        for (final list in _shoppingLists)
          _productCounts[list.id] ?? list.productIds.length,
      ].fold(0, (sum, count) => sum + count),
      receiptCount: receipts.length,
      recentReceiptItemCount: [
        for (final receipt in receipts)
          if (receipt.occurredAt.isAfter(since)) receipt.itemCount,
      ].fold(0, (sum, count) => sum + count),
    );
  }

  /// Receipts only feed an insight, so a failure never fails the dashboard.
  Future<List<ReceiptRecord>> _loadReceipts(String userId) async {
    try {
      return await _receipts.list(userId);
    } catch (e) {
      _logger.w('Could not load the dashboard receipts: $e');
      return const [];
    }
  }

  List<Collection> _ofType(List<Collection> collections, CollectionType type) =>
      [
        for (final collection in collections)
          if (collection.type == type) collection,
      ];

  /// The counts only decorate the collection cards, so a failure never fails
  /// the dashboard.
  Future<Map<String, int>> _resolveCounts(
    String userId,
    List<Collection> collections,
  ) async {
    if (collections.isEmpty) return const {};
    try {
      return await _collectionService.resolveCounts(userId, collections);
    } catch (e) {
      _logger.w('Could not resolve the dashboard product counts: $e');
      return const {};
    }
  }

  /// Refreshes the synced preferences, then reloads, so a window changed on
  /// another device applies on pull-to-refresh.
  Future<void> refresh() async {
    await _preferences.load();
    await load();
  }

  /// Reloads when a synced or edited preference changes the expiring-soon
  /// window after the dashboard was already loaded. Errors on this background
  /// path are logged; the next explicit refresh surfaces them.
  void _onPreferencesChanged() {
    final loaded = _loadedExpiringSoonDays;
    if (loaded != null && loaded != _preferences.expiringSoonDays) {
      unawaited(
        load().catchError((Object e) {
          _logger.w('Dashboard reload after a preference change failed: $e');
        }),
      );
    }
  }

  @override
  void dispose() {
    _preferences.removeListener(_onPreferencesChanged);
    super.dispose();
  }
}
