import 'package:flutter/foundation.dart';

import '../interfaces/i_auth_service.dart';
import '../models/product_model.dart';
import '../services/collection_service.dart';
import '../services/open_food_facts_client.dart';
import '../services/product_service.dart';
import '../utils/product_add_helper.dart' show BarcodeScanAction;
import 'preferences_controller.dart';

/// One expiry saved during a batch session.
class RegisteredExpiry {
  final String name;
  final DateTime date;
  final int quantity;

  const RegisteredExpiry({
    required this.name,
    required this.date,
    required this.quantity,
  });
}

/// State of a batch expiry session: pick or create a product, capture its
/// expiry, save, repeat.
class BatchExpiryController extends ChangeNotifier {
  final ProductService _products;
  final CollectionService _collections;
  final PreferencesController _preferences;
  final IAuthService _auth;
  final String? collectionId;

  BatchExpiryController({
    required ProductService products,
    required CollectionService collections,
    required PreferencesController preferences,
    required IAuthService auth,
    this.collectionId,
  }) : _products = products,
       _collections = collections,
       _preferences = preferences,
       _auth = auth;

  List<Product> owned = [];
  Product? selected;
  bool creating = false;
  String draftName = '';
  String? draftBarcode;
  DateTime? date;
  int quantity = 1;
  bool saving = false;
  final List<RegisteredExpiry> registered = [];

  bool get hasProduct => selected != null || creating;

  String get productName => selected?.name ?? draftName;

  bool get canSave =>
      hasProduct &&
      date != null &&
      !saving &&
      (selected != null || draftName.trim().isNotEmpty);

  Future<void> load() async {
    owned = await _products.getProducts(_auth.getUserId());
    notifyListeners();
  }

  /// Own products whose name or barcode contains [query].
  List<Product> matches(String query) {
    final needle = query.trim().toLowerCase();
    if (needle.isEmpty) return const [];
    return [
      for (final product in owned)
        if (product.name.toLowerCase().contains(needle) ||
            (product.barcode?.contains(needle) ?? false))
          product,
    ];
  }

  void select(Product product) {
    selected = product;
    creating = false;
    notifyListeners();
  }

  void startNew(String name, {String? barcode}) {
    selected = null;
    creating = true;
    draftName = name;
    draftBarcode = barcode;
    notifyListeners();
  }

  void setName(String name) {
    draftName = name;
    notifyListeners();
  }

  void clearProduct() {
    selected = null;
    creating = false;
    draftName = '';
    draftBarcode = null;
    notifyListeners();
  }

  void setDate(DateTime value) {
    date = value;
    notifyListeners();
  }

  void setQuantity(int value) {
    if (value < 1) return;
    quantity = value;
    notifyListeners();
  }

  /// Applies what the barcode scanner returned: an owned product is selected,
  /// an unknown barcode starts a new product named from Open Food Facts.
  Future<void> handleScan(Object? result, String languageCode) async {
    switch (result) {
      case BarcodeScanAction.addWithoutBarcode:
        startNew('');
      case OffProductData(:final barcode, :final name):
        if (barcode == null) return startNew(name ?? '');
        await _handleBarcode(barcode, languageCode, name: name);
      case String barcode when barcode.isNotEmpty:
        await _handleBarcode(barcode, languageCode);
    }
  }

  Future<void> _handleBarcode(
    String barcode,
    String languageCode, {
    String? name,
  }) async {
    final userId = _auth.getUserId();
    final existing = userId == null
        ? null
        : await _products.findOwnedByBarcode(userId, barcode);
    if (existing != null) return select(existing);
    var resolved = name;
    if (resolved == null) {
      final lookup = await _products.lookupByBarcode(
        userId: userId,
        barcode: barcode,
        languageCode: languageCode,
      );
      resolved = lookup.exact ? lookup.candidates.first.name : null;
    }
    startNew(resolved ?? '', barcode: ProductService.normalizeBarcode(barcode));
  }

  /// Saves the expiry on the selected or new product and resets the form. A
  /// failure to place a new product in its inventory is thrown after the
  /// expiry itself was registered.
  Future<void> save() async {
    final expiry = date;
    if (!canSave || expiry == null) return;
    saving = true;
    notifyListeners();
    String? newProductId;
    try {
      final Product saved;
      if (selected case final product?) {
        saved = await _products.addExpiry(
          product.id,
          expiry,
          quantity: quantity,
        );
      } else {
        final userId = _auth.getUserId();
        if (userId == null) throw StateError('No signed-in user');
        saved = await _products.createProduct(
          Product(
            id: '',
            name: draftName.trim(),
            description: '',
            userId: userId,
            barcode: draftBarcode,
            expiries: [ExpiryEntry(quantity: quantity, expirationDate: expiry)],
          ),
        );
        newProductId = saved.id;
      }
      registered.insert(
        0,
        RegisteredExpiry(name: saved.name, date: expiry, quantity: quantity),
      );
      clearProduct();
      date = null;
      quantity = 1;
    } finally {
      saving = false;
      notifyListeners();
    }
    if (newProductId != null) {
      final target =
          collectionId ?? await _preferences.resolveDefaultInventoryId();
      if (target != null) {
        await _collections.addProductToCollection(target, newProductId);
      }
    }
    await load();
  }
}
