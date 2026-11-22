import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:injectable/injectable.dart';

import '../interfaces/i_auth_service.dart';
import '../models/collection_model.dart';
import '../models/product_model.dart';
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

  DashboardController(
    this._authService,
    this._productService,
    this._collectionService,
    this._preferences,
  ) {
    _preferences.addListener(_onPreferencesChanged);
  }

  List<Product> _expiringSoon = const [];
  List<Collection> _inventories = const [];
  int _loadGeneration = 0;
  int? _loadedExpiringSoonDays;

  List<Product> get expiringSoon => _expiringSoon;
  List<Collection> get inventories => _inventories;

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
      _expiringSoon = const [];
      _inventories = const [];
      notifyListeners();
      return;
    }

    final results = await Future.wait([
      _productService.getExpiringSoon(
        userId,
        expiringSoonDays: expiringSoonDays,
      ),
      _collectionService.getCollectionsForUser(
        userId,
        type: CollectionType.inventory,
      ),
    ]);

    if (generation != _loadGeneration) return;

    _expiringSoon = results[0] as List<Product>;
    _inventories = results[1] as List<Collection>;
    notifyListeners();
  }

  /// Reloads when a synced or edited preference changes the expiring-soon
  /// window after the dashboard was already loaded.
  void _onPreferencesChanged() {
    final loaded = _loadedExpiringSoonDays;
    if (loaded != null && loaded != _preferences.expiringSoonDays) {
      unawaited(load());
    }
  }

  @override
  void dispose() {
    _preferences.removeListener(_onPreferencesChanged);
    super.dispose();
  }
}
