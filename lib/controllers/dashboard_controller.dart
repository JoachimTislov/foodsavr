import 'package:flutter/foundation.dart';
import 'package:injectable/injectable.dart';

import '../interfaces/i_auth_service.dart';
import '../models/collection_model.dart';
import '../models/product_model.dart';
import '../services/collection_service.dart';
import '../services/product_service.dart';
import '../utils/collection_types.dart';

/// Holds the dashboard state and the logic to load it, keeping the view free
/// of service logic and manual setState calls. The view rebuilds reactively
/// via watch_it when this notifier changes.
@lazySingleton
class DashboardController extends ChangeNotifier {
  final IAuthService _authService;
  final ProductService _productService;
  final CollectionService _collectionService;

  DashboardController(
    this._authService,
    this._productService,
    this._collectionService,
  );

  List<Product> _expiringSoon = const [];
  List<Collection> _inventories = const [];

  List<Product> get expiringSoon => _expiringSoon;
  List<Collection> get inventories => _inventories;

  /// Loads the dashboard data for the current user and notifies listeners.
  /// Completes normally when there is no signed-in user (state is cleared).
  Future<void> load() async {
    final userId = _authService.getUserId();
    if (userId == null) {
      _expiringSoon = const [];
      _inventories = const [];
      notifyListeners();
      return;
    }

    final results = await Future.wait([
      _productService.getExpiringSoon(userId),
      _collectionService.getCollectionsForUser(
        userId,
        type: CollectionType.inventory,
      ),
    ]);

    _expiringSoon = results[0] as List<Product>;
    _inventories = results[1] as List<Collection>;
    notifyListeners();
  }
}
