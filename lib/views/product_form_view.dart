import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:watch_it/watch_it.dart';
import '../models/product_model.dart';
import '../service_locator.dart';
import '../services/product_service.dart';
import '../services/collection_service.dart';
import '../interfaces/i_auth_service.dart';
import '../widgets/product/quantity_section.dart';
import '../widgets/product/expiries_section.dart';
import '../constants/product_categories.dart';

class ProductFormView extends StatelessWidget {
  final Product? product;
  final String? initialCollectionId;

  const ProductFormView({super.key, this.product, this.initialCollectionId});

  /// Shows the product form as a centered dialog.
  /// Returns `true` if a product was saved.
  static Future<bool?> show(
    BuildContext context, {
    Product? product,
    String? collectionId,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 450, maxHeight: 600),
          child: _ProductFormContent(
            product: product,
            initialCollectionId: collectionId,
          ),
        ),
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
  final String? initialCollectionId;

  const _ProductFormContent({this.product, this.initialCollectionId});

  @override
  State<_ProductFormContent> createState() => _ProductFormContentState();
}

class _ProductFormContentState extends State<_ProductFormContent>
    with WatchItStatefulWidgetMixin {
  final _formKey = GlobalKey<FormState>();
  late final ProductService _productService;
  late final CollectionService _collectionService;
  late final IAuthService _authService;

  late TextEditingController _nameController;
  late TextEditingController _descriptionController;
  late final ValueNotifier<String?> _selectedCategory;
  late final ValueNotifier<int> _nonExpiringQuantity;
  late final ValueNotifier<List<ExpiryEntry>> _expiries;
  final _isSaving = ValueNotifier<bool>(false);

  @override
  void initState() {
    super.initState();
    _productService = getIt<ProductService>();
    _collectionService = getIt<CollectionService>();
    _authService = getIt<IAuthService>();

    _nameController = TextEditingController(text: widget.product?.name ?? '');
    _descriptionController = TextEditingController(
      text: widget.product?.description ?? '',
    );
    _selectedCategory = ValueNotifier<String?>(widget.product?.category);
    _nonExpiringQuantity = ValueNotifier<int>(
      widget.product?.nonExpiringQuantity ?? 0,
    );
    _expiries = ValueNotifier<List<ExpiryEntry>>(
      List<ExpiryEntry>.from(widget.product?.expiries ?? const []),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _selectedCategory.dispose();
    _nonExpiringQuantity.dispose();
    _expiries.dispose();
    _isSaving.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final userId = _authService.getUserId();
    if (userId == null) return;

    _isSaving.value = true;

    try {
      final productId =
          widget.product?.id ?? DateTime.now().millisecondsSinceEpoch;
      final product = Product(
        id: productId,
        name: _nameController.text,
        description: _descriptionController.text,
        userId: userId,
        expiries: _expiries.value,
        nonExpiringQuantity: _nonExpiringQuantity.value,
        category: _selectedCategory.value,
        isGlobal: widget.product?.isGlobal ?? false,
      );

      if (widget.product == null) {
        await _productService.addProduct(product);
        if (widget.initialCollectionId != null) {
          final collection = await _collectionService.getCollection(
            widget.initialCollectionId!,
          );
          if (collection != null && collection.userId == userId) {
            await _collectionService.addProductToCollection(
              widget.initialCollectionId!,
              productId,
            );
          }
        }
      } else {
        await _productService.updateProduct(product);
      }

      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to save product: $e')));
      }
    } finally {
      if (mounted) {
        _isSaving.value = false;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedCategory = watch(_selectedCategory).value;
    final nonExpiringQuantity = watch(_nonExpiringQuantity).value;
    final expiries = watch(_expiries).value;
    final isSaving = watch(_isSaving).value;
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
          child: Text(
            widget.product == null ? 'product.add'.tr() : 'product.edit'.tr(),
            style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
        ),
        const Divider(),
        Flexible(
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
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
                  initialValue: selectedCategory,
                  decoration: InputDecoration(
                    labelText: 'product.category'.tr(),
                    border: const OutlineInputBorder(),
                  ),
                  items: ProductCategory.allNames.map((cat) {
                    return DropdownMenuItem(value: cat, child: Text(cat));
                  }).toList(),
                  onChanged: (val) => _selectedCategory.value = val,
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
                  quantity: nonExpiringQuantity,
                  onChanged: (val) => _nonExpiringQuantity.value = val,
                ),
                const SizedBox(height: 24),
                ExpiriesSection(
                  expiries: expiries,
                  onAdd: _addExpiry,
                  onRemove: (idx) {
                    final updated = List<ExpiryEntry>.from(_expiries.value)
                      ..removeAt(idx);
                    _expiries.value = updated;
                  },
                ),
              ],
            ),
          ),
        ),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            width: double.infinity,
              child: FilledButton(
                onPressed: isSaving ? null : _save,
                child: isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(
                      widget.product == null
                          ? 'common.create'.tr()
                          : 'common.save'.tr(),
                    ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _addExpiry() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 7)),
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 10)),
    );

    if (date != null && mounted) {
      _expiries.value = List<ExpiryEntry>.from(_expiries.value)
        ..add(ExpiryEntry(quantity: 1, expirationDate: date));
    }
  }
}
