import 'dart:math';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:watch_it/watch_it.dart';
import '../models/product_model.dart';
import '../service_locator.dart';
import '../services/collection_service.dart';
import '../services/product_service.dart';
import '../interfaces/i_auth_service.dart';
import '../constants/product_categories.dart';

class ProductFormView extends StatelessWidget {
  final Product? product;
  final String? initialCollectionId;

  const ProductFormView({super.key, this.product, this.initialCollectionId});

  static Future<bool?> show(BuildContext context,
      {Product? product, String? initialCollectionId}) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _ProductFormContent(
        product: product,
        initialCollectionId: initialCollectionId,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}

class _ProductFormContent extends StatefulWidget with WatchItStatefulWidgetMixin {
  final Product? product;
  final String? initialCollectionId;

  const _ProductFormContent({this.product, this.initialCollectionId});

  @override
  State<_ProductFormContent> createState() => _ProductFormContentState();
}

class _ProductFormContentState extends State<_ProductFormContent> with WatchItMixin {
  static final Random _random = Random();
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
    _descriptionController =
        TextEditingController(text: widget.product?.description ?? '');
    _selectedCategory = ValueNotifier<String?>(
      widget.product?.category ?? ProductCategory.general,
    );
    _nonExpiringQuantity = ValueNotifier<int>(
      widget.product?.nonExpiringQuantity ?? 1,
    );
    _expiries = ValueNotifier<List<ExpiryEntry>>(
      widget.product?.expiries ?? [],
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
      if (widget.product != null) {
        final updated = widget.product!.copyWith(
          name: _nameController.text,
          description: _descriptionController.text,
          category: _selectedCategory.value ?? ProductCategory.general,
          nonExpiringQuantity: _nonExpiringQuantity.value,
          expiries: _expiries.value,
        );
        await _productService.updateProduct(updated);
      } else {
        // If it's a new product, we first create it in the 'personal' registry
        // then add a 'current' mapping to the selected collection
        final personalProductId = _generateProductId();
        final product = Product(
          id: _generateProductId(),
          name: _nameController.text,
          description: _descriptionController.text,
          userId: userId,
          category: _selectedCategory.value ?? ProductCategory.general,
          nonExpiringQuantity: _nonExpiringQuantity.value,
          expiries: _expiries.value,
          registryType: 'current',
          mappedFromProductId: personalProductId,
        );

        if (widget.initialCollectionId != null) {
          // Logic for personal product creation
          final personalProduct = Product(
            id: personalProductId,
            name: _nameController.text,
            description: _descriptionController.text,
            userId: userId,
            category: _selectedCategory.value,
            registryType: 'personal',
          );
          await _productService.addProduct(personalProduct);
          await _productService.addProduct(
            product.copyWith(
              name: product.name,
              description: product.description,
              userId: userId,
              category: product.category,
              imageUrl: product.imageUrl,
              isGlobal: false,
              registryType: 'current',
              mappedFromProductId: personalProductId,
            ),
          );
        } else {
          await _productService.addProduct(product);
        }

        if (widget.initialCollectionId != null) {
          await _collectionService.addProductsToCollection(
            widget.initialCollectionId!,
            [product.id],
          );
        }
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('common.error_loading_data'.tr())),
        );
      }
    } finally {
      if (mounted) _isSaving.value = false;
    }
  }

  int _generateProductId() {
    return (DateTime.now().microsecondsSinceEpoch * 1000) +
        _random.nextInt(1000);
  }

  @override
  Widget build(BuildContext context) {
    final selectedCategory = watch(_selectedCategory).value;
    final nonExpiringQuantity = watch(_nonExpiringQuantity).value;
    final expiries = watch(_expiries).value;
    final isSaving = watch(_isSaving).value;

    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.product != null
                    ? 'product.editTitle'.tr()
                    : 'product.addTitle'.tr(),
                style: Theme.of(context).textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _nameController,
                        decoration: InputDecoration(
                          labelText: 'common.name'.tr(),
                          border: const OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'common.required'.tr();
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _descriptionController,
                        decoration: InputDecoration(
                          labelText: 'common.description'.tr(),
                          border: const OutlineInputBorder(),
                        ),
                        maxLines: 2,
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        value: selectedCategory,
                        decoration: InputDecoration(
                          labelText: 'product.category'.tr(),
                          border: const OutlineInputBorder(),
                        ),
                        items: ProductCategory.allNames.map((cat) {
                          return DropdownMenuItem(
                            value: cat,
                            child: Text(cat),
                          );
                        }).toList(),
                        onChanged: (val) => _selectedCategory.value = val,
                      ),
                      const SizedBox(height: 24),
                      _buildQuantitySection(nonExpiringQuantity),
                      const SizedBox(height: 24),
                      _buildExpirySection(expiries),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: isSaving ? null : _save,
                child: isSaving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text('common.save'.tr()),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuantitySection(int quantity) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'product.quantity'.tr(),
          style: Theme.of(context).textTheme.titleSmall,
        ),
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.remove),
              onPressed: quantity > 0
                  ? () => _nonExpiringQuantity.value = quantity - 1
                  : null,
            ),
            Text(quantity.toString(),
                style: Theme.of(context).textTheme.titleMedium),
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: () => _nonExpiringQuantity.value = quantity + 1,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildExpirySection(List<ExpiryEntry> expiries) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'product.expiries'.tr(),
              style: Theme.of(context).textTheme.titleSmall,
            ),
            TextButton.icon(
              onPressed: _addExpiry,
              icon: const Icon(Icons.add),
              label: Text('product.addExpiry'.tr()),
            ),
          ],
        ),
        ...expiries.asMap().entries.map((entry) {
          final idx = entry.key;
          final expiry = entry.value;
          return ListTile(
            title: Text(DateFormat.yMd().format(expiry.expirationDate)),
            subtitle: Text('product.quantity'.tr() + ': ${expiry.quantity}'),
            trailing: IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: () {
                final newExpiries = List<ExpiryEntry>.from(_expiries.value);
                newExpiries.removeAt(idx);
                _expiries.value = newExpiries;
              },
            ),
          );
        }),
      ],
    );
  }

  Future<void> _addExpiry() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 10)),
    );

    if (date != null && mounted) {
      _expiries.value = List<ExpiryEntry>.from(_expiries.value)
        ..add(ExpiryEntry(quantity: 1, expirationDate: date));
    }
  }
}
