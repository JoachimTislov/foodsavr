import 'package:flutter/foundation.dart';

import '../models/collection_model.dart';
import '../utils/collection_types.dart';

/// Manages the filtered collection list state for a collection list view,
/// keeping the view free of service logic and manual setState calls.
class CollectionListController extends ChangeNotifier {
  List<Collection> _collections = const [];

  List<Collection> get collections => _collections;

  /// Applies the type filter to the fetched collections and notifies.
  void loadCollections(List<Collection> all, CollectionType? typeFilter) {
    final filtered = typeFilter != null
        ? all.where((c) => c.type == typeFilter).toList()
        : all.where((c) => c.type == CollectionType.inventory).toList();
    _collections = filtered;
    notifyListeners();
  }

  /// Clears the list and notifies (e.g. signed-out user).
  void clear() {
    _collections = const [];
    notifyListeners();
  }
}
