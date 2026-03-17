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

  static Future<bool?> show(
    BuildContext context, {
    Product? product,
    String? initialCollectionId,
  }) {
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

class _ProductFormContent extends WatchingWidget {
  final Product? product;
  final String? initialCollectionId;

  const _ProductFormContent({this.product, this.initialCollectionId});

  @override
  Widget build(BuildContext context) {
    final productService = getIt<ProductService>();
    final collectionService = getIt<CollectionService>();
    final authService = getIt<IAuthService>();

    final nameController = createOnce(
      () => TextEditingController(text: product?.name ?? ''),
    );
    final descriptionController = createOnce(
      () => TextEditingController(text: product?.description ?? ''),
    );
    final selectedCategory = createOnce(
      () =>
          ValueNotifier<String?>(product?.category ?? ProductCategory.general),
    );
    final nonExpiringQuantity = createOnce(
      () => ValueNotifier<int>(product?.nonExpiringQuantity ?? 1),
    );
    final expiries = createOnce(
      () => ValueNotifier<List<ExpiryEntry>>(product?.expiries ?? []),
    );
    final isSaving = createOnce(() => ValueNotifier<bool>(false));
    final formKey = createOnce(() => GlobalKey<FormState>());

    final currentCategory = watch(selectedCategory).value;
    final currentNonExpiringQuantity = watch(nonExpiringQuantity).value;
    final currentExpiries = watch(expiries).value;
    final saving = watch(isSaving).value;

    int generateProductId() {
      return (DateTime.now().microsecondsSinceEpoch * 1000) +
          Random().nextInt(1000);
    }

    Future<void> save() async {
      if (!formKey.currentState!.validate()) return;

      final userId = authService.getUserId();
      if (userId == null) return;

      isSaving.value = true;
      try {
        if (product != null) {
          final updated = product!.copyWith(
            name: nameController.text,
            description: descriptionController.text,
            category: selectedCategory.value ?? ProductCategory.general,
            nonExpiringQuantity: nonExpiringQuantity.value,
            expiries: expiries.value,
          );
          await productService.updateProduct(updated);
        } else {
          final personalProductId = generateProductId();
          final newProduct = Product(
            id: generateProductId(),
            name: nameController.text,
            description: descriptionController.text,
            userId: userId,
            category: selectedCategory.value ?? ProductCategory.general,
            nonExpiringQuantity: nonExpiringQuantity.value,
            expiries: expiries.value,
            registryType: 'current',
            mappedFromProductId: personalProductId,
          );

          if (initialCollectionId != null) {
            final personalProduct = Product(
              id: personalProductId,
              name: nameController.text,
              description: descriptionController.text,
              userId: userId,
              category: selectedCategory.value ?? ProductCategory.general,
              registryType: 'personal',
            );
            await productService.addProduct(personalProduct);
            await productService.addProduct(newProduct);
            await collectionService.addProductsToCollection(
              initialCollectionId!,
              [newProduct.id],
            );
          } else {
            await productService.addProduct(newProduct);
          }
        }
        if (context.mounted) Navigator.of(context).pop(true);
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('common.error_loading_data'.tr())),
          );
        }
      } finally {
        if (context.mounted) isSaving.value = false;
      }
    }

    Future<void> addExpiry() async {
      final date = await showDatePicker(
        context: context,
        initialDate: DateTime.now(),
        firstDate: DateTime.now(),
        lastDate: DateTime.now().add(const Duration(days: 365 * 10)),
      );

      if (date != null && context.mounted) {
        expiries.value = List<ExpiryEntry>.from(expiries.value)
          ..add(ExpiryEntry(quantity: 1, expirationDate: date));
      }
    }

    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                product != null
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
                        controller: nameController,
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
                        controller: descriptionController,
                        decoration: InputDecoration(
                          labelText: 'common.description'.tr(),
                          border: const OutlineInputBorder(),
                        ),
                        maxLines: 2,
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        initialValue: currentCategory,
                        decoration: InputDecoration(
                          labelText: 'product.category'.tr(),
                          border: const OutlineInputBorder(),
                        ),
                        items: ProductCategory.allNames.map((cat) {
                          return DropdownMenuItem(value: cat, child: Text(cat));
                        }).toList(),
                        onChanged: (val) => selectedCategory.value = val,
                      ),
                      const SizedBox(height: 24),
                      _buildQuantitySection(
                        context,
                        currentNonExpiringQuantity,
                        nonExpiringQuantity,
                      ),
                      const SizedBox(height: 24),
                      _buildExpirySection(
                        context,
                        currentExpiries,
                        expiries,
                        addExpiry,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: saving ? null : save,
                child: saving
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

  Widget _buildQuantitySection(
    BuildContext context,
    int quantity,
    ValueNotifier<int> notifier,
  ) {
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
                  ? () => notifier.value = quantity - 1
                  : null,
            ),
            Text(
              quantity.toString(),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: () => notifier.value = quantity + 1,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildExpirySection(
    BuildContext context,
    List<ExpiryEntry> currentExpiries,
    ValueNotifier<List<ExpiryEntry>> notifier,
    VoidCallback onAdd,
  ) {
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
              onPressed: onAdd,
              icon: const Icon(Icons.add),
              label: Text('product.addExpiry'.tr()),
            ),
          ],
        ),
        ...currentExpiries.asMap().entries.map((entry) {
          final idx = entry.key;
          final expiry = entry.value;
          return ListTile(
            title: Text(DateFormat.yMd().format(expiry.expirationDate)),
            subtitle: Text('${'product.quantity'.tr()}: ${expiry.quantity}'),
            trailing: IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: () {
                final newExpiries = List<ExpiryEntry>.from(notifier.value);
                newExpiries.removeAt(idx);
                notifier.value = newExpiries;
              },
            ),
          );
        }),
      ],
    );
  }
}
