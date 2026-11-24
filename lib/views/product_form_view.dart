import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:foodsavr_core/foodsavr_core.dart' show ShelfLifeInferer;

import '../controllers/preferences_controller.dart';
import '../models/product_model.dart';
import '../service_locator.dart';
import '../services/product_service.dart';
import '../services/collection_service.dart';
import '../interfaces/i_auth_service.dart';
import '../widgets/product/quantity_section.dart';
import '../views/expiry_scan_view.dart';
import '../widgets/product/expiries_section.dart';
import '../constants/product_categories.dart';
import '../widgets/common/adaptive_sheet.dart';

class ProductFormView extends StatelessWidget {
  /// The existing product being edited. Mutually exclusive with [prefill].
  final Product? product;

  /// An unsaved product (for example from a barcode scan) that prefills the
  /// form; saving it creates a new product.
  final Product? prefill;
  final String? initialCollectionId;

  const ProductFormView({
    super.key,
    this.product,
    this.prefill,
    this.initialCollectionId,
  }) : assert(product == null || prefill == null);

  /// Shows the product form as a bottom sheet on Compact windows and a dialog
  /// on wider ones.
  /// Pass [product] to edit an existing product, or [prefill] to create a new
  /// one from partial data. Returns `true` if a product was saved.
  static Future<bool?> show(
    BuildContext context, {
    Product? product,
    Product? prefill,
    String? collectionId,
  }) async {
    assert(product == null || prefill == null);
    // A new product without a target goes to the default inventory.
    if (product == null && collectionId == null) {
      collectionId = await getIt<PreferencesController>()
          .resolveDefaultInventoryId();
      if (!context.mounted) return null;
    }
    return AdaptiveSheet.show<bool>(
      context,
      builder: (_) => _ProductFormContent(
        product: product,
        prefill: prefill,
        initialCollectionId: collectionId,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}

class _ProductFormContent extends StatefulWidget {
  final Product? product;
  final Product? prefill;
  final String? initialCollectionId;

  const _ProductFormContent({
    this.product,
    this.prefill,
    this.initialCollectionId,
  });

  @override
  State<_ProductFormContent> createState() => _ProductFormContentState();
}

class _ProductFormContentState extends State<_ProductFormContent> {
  final _formKey = GlobalKey<FormState>();
  late final ProductService _productService;
  late final CollectionService _collectionService;
  late final IAuthService _authService;
  late final String? _userId;

  late TextEditingController _nameController;
  late TextEditingController _descriptionController;
  String? _selectedCategory;
  int _nonExpiringQuantity = 0;
  List<ExpiryEntry> _expiries = [];

  bool _isSaving = false;

  final _shelfLife = ShelfLifeInferer();

  /// Expiry pre-filled from the category; replaced while the user has not
  /// touched the expiry list.
  ExpiryEntry? _suggested;

  /// Product created by an earlier attempt whose collection assignment
  /// failed; a retry only repeats the assignment.
  Product? _created;

  bool get _isEditing => widget.product != null;

  @override
  void initState() {
    super.initState();
    _productService = getIt<ProductService>();
    _collectionService = getIt<CollectionService>();
    _authService = getIt<IAuthService>();
    _userId = _authService.getUserId();

    final source = widget.product ?? widget.prefill;
    _nameController = TextEditingController(text: source?.name ?? '');
    _descriptionController = TextEditingController(
      text: source?.description ?? '',
    );
    _selectedCategory = source?.category;
    _nonExpiringQuantity = source?.nonExpiringQuantity ?? 0;
    _expiries = List.from(source?.expiries ?? []);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final userId = _userId;
    if (!_formKey.currentState!.validate() || userId == null) return;

    setState(() => _isSaving = true);

    try {
      // Start from the source product so fields the form does not show
      // (barcode, image, tags, registry mapping) survive the save.
      final base =
          widget.product ??
          widget.prefill ??
          Product(id: '', name: '', description: '', userId: userId);
      final product = base.copyWith(
        name: _nameController.text,
        description: _descriptionController.text,
        userId: _isEditing ? base.userId : userId,
        expiries: _expiries,
        nonExpiringQuantity: _nonExpiringQuantity,
        category: _selectedCategory,
      );

      if (_isEditing) {
        await _productService.updateProduct(product);
      } else {
        final collectionId = widget.initialCollectionId;
        final created = _created ??= await _productService.createProduct(
          product,
          withPersonalTemplate: collectionId != null,
        );
        if (collectionId != null) {
          final collection = await _collectionService.getCollection(
            collectionId,
          );
          if (collection != null && collection.userId == userId) {
            await _collectionService.addProductToCollection(
              collectionId,
              created.id,
            );
          }
        }
      }

      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('product.saveError'.tr(namedArgs: {'error': '$e'})),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            _isEditing ? 'product.edit'.tr() : 'product.add'.tr(),
            style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
        ),
        const Divider(),
        Flexible(
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              shrinkWrap: true,
              children: [
                TextFormField(
                  controller: _nameController,
                  autofocus: true,
                  decoration: InputDecoration(
                    labelText: 'product.name'.tr(),
                    border: const OutlineInputBorder(),
                  ),
                  validator: (value) => value == null || value.isEmpty
                      ? 'product.name_required'.tr()
                      : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _descriptionController,
                  decoration: InputDecoration(
                    labelText: 'product.description'.tr(),
                    border: const OutlineInputBorder(),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: _selectedCategory,
                  decoration: InputDecoration(
                    labelText: 'product.category'.tr(),
                    border: const OutlineInputBorder(),
                  ),
                  items: ProductCategory.allNames.map((cat) {
                    return DropdownMenuItem(value: cat, child: Text(cat));
                  }).toList(),
                  onChanged: _onCategoryChanged,
                ),
                const SizedBox(height: 24),
                Text(
                  'product.inventory'.tr(),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                QuantitySection(
                  quantity: _nonExpiringQuantity,
                  onChanged: (val) =>
                      setState(() => _nonExpiringQuantity = val),
                ),
                const SizedBox(height: 24),
                ExpiriesSection(
                  expiries: _expiries,
                  onAdd: _addExpiry,
                  onScan: _scanExpiry,
                  onRemove: (idx) => setState(() {
                    if (identical(_expiries[idx], _suggested)) {
                      _suggested = null;
                    }
                    _expiries.removeAt(idx);
                  }),
                ),
              ],
            ),
          ),
        ),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.only(top: 16),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _isSaving ? null : _save,
              child: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(
                      _isEditing ? 'common.save'.tr() : 'common.create'.tr(),
                    ),
            ),
          ),
        ),
      ],
    );
  }

  DateTime? _estimatedExpiry() {
    final estimate = _shelfLife.estimate(
      category: _selectedCategory,
      normalizedName: _nameController.text.trim().toLowerCase(),
    );
    if (estimate == null) return null;
    return DateUtils.dateOnly(
      DateTime.now().add(Duration(days: estimate.days)),
    );
  }

  /// Pre-fills the first expiry from the chosen category on a new product;
  /// the user can change or remove it.
  void _onCategoryChanged(String? category) {
    setState(() {
      _selectedCategory = category;
      if (_isEditing) return;
      final untouched =
          _expiries.isEmpty ||
          (_expiries.length == 1 && identical(_expiries.first, _suggested));
      if (!untouched) return;
      _expiries.clear();
      _suggested = null;
      final date = _estimatedExpiry();
      if (date == null) return;
      _suggested = ExpiryEntry(quantity: 1, expirationDate: date);
      _expiries.add(_suggested!);
    });
  }

  Future<void> _scanExpiry() async {
    final date = await Navigator.of(context, rootNavigator: true)
        .push<DateTime>(
          MaterialPageRoute(
            fullscreenDialog: true,
            builder: (context) => const ExpiryScanView(),
          ),
        );
    if (date != null && mounted) {
      setState(() {
        _expiries.add(ExpiryEntry(quantity: 1, expirationDate: date));
      });
    }
  }

  Future<void> _addExpiry() async {
    final date = await showDatePicker(
      context: context,
      initialDate:
          _estimatedExpiry() ??
          DateTime.now().add(
            Duration(days: getIt<PreferencesController>().expiringSoonDays + 1),
          ),
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 10)),
    );

    if (date != null && mounted) {
      setState(() {
        _expiries.add(ExpiryEntry(quantity: 1, expirationDate: date));
      });
    }
  }
}
