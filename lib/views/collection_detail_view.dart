import 'dart:async';
import 'dart:math' as math;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../controllers/list_query_state.dart';
import '../controllers/preferences_controller.dart';
import '../models/collection_model.dart';
import '../models/product_model.dart';
import '../utils/collection_types.dart';
import '../utils/product_add_helper.dart';
import '../service_locator.dart';
import '../services/product_service.dart';
import '../services/collection_service.dart';
import '../services/barcode_scanner_service.dart';
import '../services/purchase_history_service.dart';
import '../widgets/collection/collection_header.dart';
import '../widgets/collection/delete_collection_sheet.dart';
import '../widgets/collection/quick_import_shopping_dialog.dart';
import '../widgets/common/content_constraint.dart';
import '../widgets/common/retry_scaffold.dart';
import '../widgets/common/empty_state_widget.dart';
import 'add_product_to_collection_view.dart';
import '../widgets/inventory/list_query_controls.dart';
import '../widgets/product/product_card_compact.dart';
import '../widgets/product/product_card_details.dart';
import '../widgets/product/product_card_normal.dart';
import '../widgets/collection/shopping_list_item_card.dart';
import '../widgets/product/view_mode_toggle.dart';
import '../utils/view_mode_helper.dart';
import 'product_detail_view.dart';
import 'collection_form_view.dart';
import 'product_form_view.dart';
import 'receipt_scan_view.dart';

class CollectionDetailView extends StatefulWidget {
  final Collection collection;

  /// When set, the view is embedded beside a list: it has no back button and
  /// reports an edited collection, or null once it was deleted.
  final ValueChanged<Collection?>? onChanged;

  const CollectionDetailView({
    super.key,
    required this.collection,
    this.onChanged,
  });

  @override
  State<CollectionDetailView> createState() => _CollectionDetailViewState();
}

class _CollectionDetailViewState extends State<CollectionDetailView> {
  List<Product> _products = [];
  bool _deleting = false;
  late final ProductService _productService;
  late final CollectionService _collectionService;
  late Collection _currentCollection;
  late final ListQueryState _query;
  late final PreferencesController _preferences;
  late final PurchaseHistoryService _history = getIt<PurchaseHistoryService>();
  List<Map<String, dynamic>> _purchaseHistory = const [];

  /// Products with a change that is still being saved.
  final Set<String> _busyProductIds = {};
  bool _canScan = false;

  bool get _isShoppingList =>
      _currentCollection.type == CollectionType.shoppingList;

  @override
  void initState() {
    super.initState();
    _productService = getIt<ProductService>();
    _collectionService = getIt<CollectionService>();
    _currentCollection = widget.collection;
    _preferences = getIt<PreferencesController>();
    BarcodeScannerService.hasCamera().then((value) {
      if (mounted) setState(() => _canScan = value);
    });
    _query = ListQueryState(
      'collection.${widget.collection.userId}.${widget.collection.id}',
    );
  }

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  Future<void> _refreshCollectionAndProducts() async {
    await _query.restore();
    final updated = await _collectionService.getCollection(
      _currentCollection.id,
    );
    if (updated == null) throw StateError('The collection is unavailable.');
    final (collection, products) = await _collectionService.loadContents(
      updated,
    );
    if (!mounted) return;
    setState(() {
      _currentCollection = collection;
      _products = products;
    });
    await _loadPurchaseHistory();
  }

  Future<void> _openAddProducts() async {
    final result = _isShoppingList
        ? await AddProductToCollectionView.show(context, _currentCollection.id)
        : await ProductAddHelper.startAddProductFlow(
            context,
            collectionId: _currentCollection.id,
          );
    if (!mounted) return;
    if (result == true) {
      await _refreshCollectionAndProducts();
      if (mounted) widget.onChanged?.call(_currentCollection);
    }
  }

  Future<void> _openQuickImport() async {
    final result = await QuickImportShoppingDialog.show(
      context,
      collectionId: _currentCollection.id,
    );
    if (!mounted) return;
    if (result == true) {
      await _refreshCollectionAndProducts();
      if (mounted) widget.onChanged?.call(_currentCollection);
    }
  }

  Future<void> _deleteCollection() async {
    setState(() => _deleting = true);
    try {
      final source = await _collectionService.getCollection(
        _currentCollection.id,
      );
      if (source == null) throw StateError('The collection is unavailable.');
      // Another device may have changed the members since this view loaded.
      // Dangling IDs never count; an unconfirmed result never offers fewer
      // choices than the loaded products need.
      var productCount = _products.length;
      try {
        final (collection, products, :authoritative) = await _collectionService
            .resolveContents(source);
        if (!mounted) return;
        setState(() {
          _currentCollection = collection;
          _products = products;
        });
        productCount = authoritative
            ? products.length
            : math.max(productCount, products.length);
      } on Exception {
        // Keep the loaded count.
      }
      final inventories =
          source.type == CollectionType.shoppingList || productCount == 0
          ? const <Collection>[]
          : await _collectionService.getCollectionsForUser(
              source.userId,
              type: CollectionType.inventory,
            );
      if (!mounted) return;
      final choice = await DeleteCollectionSheet.show(
        context,
        collection: source,
        productCount: productCount,
        destinations: inventories
            .where((item) => item.id != source.id)
            .toList(),
      );
      if (choice == null || !mounted) return;
      if (choice.deleteProducts || choice.destinationId != null) {
        await _productService.deleteCollection(
          source,
          destinationId: choice.destinationId,
        );
      } else {
        await _collectionService.deleteCollectionOnly(source.id);
      }
      // Not awaited: an offline save completes only once the server has it.
      unawaited(_preferences.forgetDefaultInventory(source.id));
      if (!mounted) return;
      final onChanged = widget.onChanged;
      if (onChanged == null) {
        Navigator.of(context).pop(true);
      } else {
        onChanged(null);
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('collection.deleteError'.tr())));
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  Future<void> _loadPurchaseHistory() async {
    if (!_isShoppingList) return;
    final history = await _history.load(_currentCollection.userId);
    if (mounted) setState(() => _purchaseHistory = history);
  }

  /// A history failure is reported on its own: the purchase already happened,
  /// so it must not be repeated.
  /// Returns the newest saved entry, or null when nothing was saved.
  Future<Map<String, dynamic>?> _recordPurchases(
    List<Product> products,
    PurchaseSource source,
  ) async {
    if (products.isEmpty) return null;
    try {
      final history = await _history.record(
        _currentCollection.userId,
        products,
        source,
      );
      if (mounted) setState(() => _purchaseHistory = history);
      return history.first;
    } catch (_) {
      _showMessage('collection.purchaseHistoryError'.tr());
      return null;
    }
  }

  /// Undoes [purchase] after the server rejected the item's removal, which
  /// puts the item back on the list.
  Future<void> _withdrawPurchase(Future<Map<String, dynamic>?> purchase) async {
    final entry = await purchase;
    try {
      if (entry != null) {
        final history = await _history.withdraw(
          _currentCollection.userId,
          entry,
        );
        if (mounted) setState(() => _purchaseHistory = history);
      }
      _showMessage('product.saveError'.tr());
      if (mounted) await _refreshCollectionAndProducts();
    } catch (_) {
      _showMessage('collection.purchaseHistoryError'.tr());
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  /// Runs [change] unless another change to [productId] is still pending.
  Future<void> _changeItem(
    String productId,
    Future<void> Function() change,
  ) async {
    if (!_busyProductIds.add(productId)) return;
    setState(() {});
    try {
      await change();
    } finally {
      _busyProductIds.remove(productId);
      if (mounted) setState(() {});
    }
  }

  Future<void> _markBought(Product product) =>
      _changeItem(product.id, () async {
        final purchase = Completer<Map<String, dynamic>?>();
        try {
          await _collectionService.removeProductFromCollection(
            _currentCollection.id,
            product.id,
            onRejected: () => unawaited(_withdrawPurchase(purchase.future)),
          );
        } catch (_) {
          _showMessage('product.saveError'.tr());
          return;
        }
        // The row goes at once, so a failed refresh cannot offer it again.
        if (mounted) {
          setState(
            () => _products = [
              for (final item in _products)
                if (item.id != product.id) item,
            ],
          );
        }
        purchase.complete(
          await _recordPurchases([product], PurchaseSource.manual),
        );
        if (mounted) await _refreshCollectionAndProducts();
      });

  Future<void> _adjustQuantity(Product product, int delta) =>
      _changeItem(product.id, () async {
        try {
          // The row may be stale, so the change applies to the stored product.
          final stored = await _productService.getProductById(product.id);
          if (stored == null) throw StateError('The product is unavailable.');
          await _productService.updateProduct(stored.adjustQuantity(delta));
          if (mounted) await _refreshCollectionAndProducts();
        } catch (_) {
          _showMessage('product.saveError'.tr());
        }
      });

  Future<void> _editProduct(Product product) async {
    final result = await ProductFormView.show(context, product: product);
    if (result == true && mounted) await _refreshCollectionAndProducts();
  }

  Future<void> _moveProduct(Product product) async {
    final userId = _currentCollection.userId;
    final inventories = await _collectionService.getCollectionsForUser(
      userId,
      type: CollectionType.inventory,
    );
    if (!mounted || inventories.isEmpty) return;
    final destination = await showDialog<Collection>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text('collection.moveDestination'.tr()),
        children: [
          for (final inventory in inventories)
            if (inventory.id != _currentCollection.id)
              SimpleDialogOption(
                onPressed: () => Navigator.pop(context, inventory),
                child: Text(inventory.name),
              ),
        ],
      ),
    );
    if (destination == null || !mounted) return;
    await _changeItem(product.id, () async {
      try {
        await _collectionService.moveProduct(
          _currentCollection.id,
          destination.id,
          product.id,
          onRejected: () => unawaited(_reportRejectedMove()),
        );
      } catch (_) {
        _showMessage('collection.moveError'.tr());
        return;
      }
      if (mounted) await _refreshCollectionAndProducts();
    });
  }

  /// The server's rejection rolls the move back, so the list is reloaded.
  Future<void> _reportRejectedMove() async {
    _showMessage('collection.moveError'.tr());
    try {
      if (mounted) await _refreshCollectionAndProducts();
    } catch (_) {
      _showMessage('collection.errorLoadingProducts'.tr());
    }
  }

  Future<void> _duplicateProduct(Product product) async {
    final userId = _currentCollection.userId;
    final inventories = await _collectionService.getCollectionsForUser(
      userId,
      type: CollectionType.inventory,
    );
    if (!mounted || inventories.isEmpty) return;
    final destination = inventories.firstWhere(
      (item) => item.id != _currentCollection.id,
      orElse: () => inventories.first,
    );
    await _changeItem(product.id, () async {
      try {
        await _createInCollection(product.copyWith(id: ''), destination.id);
      } catch (_) {
        _showMessage('collection.duplicateError'.tr());
        return;
      }
      _showMessage('product.barcodeCreated'.tr());
    });
  }

  /// Saves [draft] as a new product in [collectionId]. It is deleted again if
  /// it cannot be added, so a retry leaves no stray copy.
  Future<void> _createInCollection(Product draft, String collectionId) async {
    final saved = await _productService.createProduct(draft);
    try {
      await _collectionService.addProductToCollection(collectionId, saved.id);
    } catch (_) {
      await _productService.deleteProduct(saved.id);
      rethrow;
    }
  }

  Future<void> _deleteProduct(Product product) =>
      _changeItem(product.id, () async {
        await _productService.deleteProduct(product.id);
        if (mounted) await _refreshCollectionAndProducts();
      });

  Future<void> _scanReceipt() async {
    final ingested = await Navigator.of(context, rootNavigator: true)
        .push<bool>(
          MaterialPageRoute(
            fullscreenDialog: true,
            builder: (context) => ReceiptScanView(
              userId: _currentCollection.userId,
              // Receipt items land in an inventory, so the scanner reports
              // them here, even when it was closed while saving them.
              onIngested: (products) =>
                  unawaited(_recordPurchases(products, PurchaseSource.receipt)),
            ),
          ),
        );
    if (ingested == true && mounted) await _refreshCollectionAndProducts();
  }

  Future<void> _reAddPurchase(Map<String, dynamic> entry) async {
    final productId = entry['productId'] as String?;
    if (productId == null || productId.isEmpty) return;
    await _changeItem(productId, () async {
      try {
        // The rules deny a direct read of a deleted product, so it is looked
        // up in the user's products.
        final products = await _productService.getProducts(
          _currentCollection.userId,
          forceRefresh: true,
        );
        if (products.any((product) => product.id == productId)) {
          await _collectionService.addProductToCollection(
            _currentCollection.id,
            productId,
          );
        } else {
          final name = entry['name']?.toString() ?? '';
          final quantity = (entry['quantity'] as num?)?.toInt() ?? 1;
          if (!mounted || !await _confirmRecreate(name, quantity)) return;
          await _createInCollection(
            Product(
              id: '',
              name: name,
              description: '',
              userId: _currentCollection.userId,
              nonExpiringQuantity: quantity,
            ),
            _currentCollection.id,
          );
        }
        if (mounted) await _refreshCollectionAndProducts();
      } catch (_) {
        _showMessage('common.somethingWentWrong'.tr());
      }
    });
  }

  Future<bool> _confirmRecreate(String name, int quantity) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('collection.recreateTitle'.tr()),
        content: Text(
          'collection.recreateMessage'.tr(
            namedArgs: {'name': name, 'quantity': '$quantity'},
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('common.cancel'.tr()),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('common.create'.tr()),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return RetryScaffold(
      errorMessage: 'collection.errorLoadingProducts'.tr(),
      onRefresh: _refreshCollectionAndProducts,
      fetchOnInit: true,
      isBodyScrollable: true,
      floatingActionButton: FloatingActionButton(
        heroTag: 'collection_detail_fab_${_currentCollection.id}',
        tooltip: 'product.add'.tr(),
        onPressed: _openAddProducts,
        child: const Icon(Icons.add),
      ),
      body: ListenableBuilder(
        listenable: Listenable.merge([_query, _preferences]),
        builder: (context, _) => _buildCollection(context),
      ),
    );
  }

  Widget _buildCollection(BuildContext context) {
    final products = _query.query.apply(
      _products,
      now: DateTime.now(),
      expiringSoonDays: _preferences.expiringSoonDays,
    );
    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverContentConstraint(
          slivers: [
            SliverToBoxAdapter(
              child: CollectionHeader(
                collection: _currentCollection,
                productCount: products.length,
                onBack:
                    widget.onChanged == null && Navigator.of(context).canPop()
                    ? () => Navigator.of(context).pop()
                    : null,
                onEdit: () async {
                  final result = await CollectionFormView.show(
                    context,
                    type: _currentCollection.type,
                    collection: _currentCollection,
                  );
                  if (result == true) {
                    await _refreshCollectionAndProducts();
                    if (mounted) widget.onChanged?.call(_currentCollection);
                  }
                },
                onDelete: _deleting ? null : _deleteCollection,
              ),
            ),
            SliverToBoxAdapter(
              child: _isShoppingList
                  ? Padding(
                      padding: const EdgeInsets.fromLTRB(12, 8, 4, 0),
                      child: Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          FilledButton.tonalIcon(
                            onPressed: _openQuickImport,
                            icon: const Icon(Icons.playlist_add),
                            label: Text('collection.quickImport.action'.tr()),
                          ),
                          FilledButton.icon(
                            onPressed: _scanReceipt,
                            icon: Icon(
                              _canScan
                                  ? Icons.receipt_long
                                  : Icons.receipt_long_outlined,
                            ),
                            label: Text('collection.scanReceipt'.tr()),
                          ),
                        ],
                      ),
                    )
                  : Align(
                      alignment: Alignment.centerRight,
                      child: ViewModeToggle(
                        viewMode: _query.viewMode,
                        onModeChanged: (mode) =>
                            _query.update(() => _query.viewMode = mode),
                      ),
                    ),
            ),
            SliverToBoxAdapter(
              child: ListQueryControls(
                state: _query,
                products: _products,
                showExpiryFilters: !_isShoppingList,
              ),
            ),
            if (products.isNotEmpty)
              SliverPadding(
                padding: const EdgeInsets.only(bottom: 80),
                sliver: SliverList.builder(
                  itemCount: products.length,
                  itemBuilder: (context, index) {
                    final product = products[index];
                    void open() => _navigateToProductDetail(product);
                    if (_isShoppingList) {
                      return ShoppingListItemCard(
                        product: product,
                        bought: false,
                        busy: _busyProductIds.contains(product.id),
                        onBoughtChanged: (_) => _markBought(product),
                        onIncrease: () => _adjustQuantity(product, 1),
                        onDecrease: () => _adjustQuantity(product, -1),
                        onTap: open,
                        onEdit: () => _editProduct(product),
                        onMove: () => _moveProduct(product),
                        onDuplicate: () => _duplicateProduct(product),
                        onDelete: () => _deleteProduct(product),
                      );
                    }
                    return switch (_query.viewMode) {
                      ProductViewMode.compact => ProductCardCompact(
                        product: product,
                        onTap: open,
                      ),
                      ProductViewMode.normal => ProductCardNormal(
                        product: product,
                        onTap: open,
                      ),
                      ProductViewMode.details => ProductCardDetails(
                        product: product,
                        onTap: open,
                      ),
                    };
                  },
                ),
              ),
          ],
        ),
        if (_isShoppingList && _purchaseHistory.isNotEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'collection.purchaseHistory'.tr(),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  for (final entry in _purchaseHistory.take(10))
                    ListTile(
                      dense: true,
                      title: Text(entry['name']?.toString() ?? ''),
                      subtitle: Text(_purchaseSummary(context, entry)),
                      trailing: TextButton(
                        onPressed: () => _reAddPurchase(entry),
                        child: Text('collection.reAdd'.tr()),
                      ),
                    ),
                ],
              ),
            ),
          ),
        if (products.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: _products.isEmpty && _isShoppingList
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          EmptyStateWidget(
                            icon: Icons.shopping_cart_outlined,
                            title: 'collection.noProducts'.tr(),
                          ),
                          const SizedBox(height: 20),
                          Wrap(
                            spacing: 12,
                            runSpacing: 8,
                            alignment: WrapAlignment.center,
                            children: [
                              FilledButton.icon(
                                onPressed: _openQuickImport,
                                icon: const Icon(Icons.playlist_add),
                                label: Text(
                                  'collection.quickImport.action'.tr(),
                                ),
                              ),
                              OutlinedButton.icon(
                                onPressed: _openAddProducts,
                                icon: const Icon(Icons.add),
                                label: Text('product.select'.tr()),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  )
                : EmptyStateWidget(
                    icon: Icons.inventory_2_outlined,
                    title: _products.isEmpty
                        ? 'collection.noProducts'.tr()
                        : 'listQuery.noMatches'.tr(),
                  ),
          ),
      ],
    );
  }

  String _purchaseSummary(BuildContext context, Map<String, dynamic> entry) {
    final source = entry['source'] == PurchaseSource.receipt.name
        ? 'collection.purchaseSourceReceipt'.tr()
        : 'collection.purchaseSourceManual'.tr();
    final purchasedAt = DateTime.tryParse('${entry['purchasedAt']}');
    return [
      '${entry['quantity']}',
      source,
      if (purchasedAt != null)
        DateFormat.yMMMd(
          context.locale.toString(),
        ).add_Hm().format(purchasedAt),
    ].join(' · ');
  }

  Future<void> _navigateToProductDetail(Product product) async {
    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ProductDetailView(product: product),
      ),
    );
    if (result == true && mounted) {
      await _refreshCollectionAndProducts();
      if (mounted) widget.onChanged?.call(_currentCollection);
    }
  }
}
