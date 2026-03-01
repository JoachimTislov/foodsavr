import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../models/product_model.dart';
import '../service_locator.dart';
import '../services/product_service.dart';
import '../services/collection_service.dart';
import '../interfaces/i_auth_service.dart';
import '../constants/product_categories.dart';

class ProductFormView extends StatefulWidget {
  final Product? product; // null if adding
  final String? initialCollectionId; // optional

  const ProductFormView({super.key, this.product, this.initialCollectionId});

  @override
  State<ProductFormView> createState() => _ProductFormViewState();
}

class _ProductFormViewState extends State<ProductFormView> {
  final _formKey = GlobalKey<FormState>();
  late final ProductService _productService;
  late final IAuthService _authService;

  late TextEditingController _nameController;
  late TextEditingController _descriptionController;
  String? _selectedCategory;
  int _nonExpiringQuantity = 0;
  List<ExpiryEntry> _expiries = [];

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _productService = getIt<ProductService>();
    _authService = getIt<IAuthService>();

    _nameController = TextEditingController(text: widget.product?.name ?? '');
    _descriptionController = TextEditingController(
      text: widget.product?.description ?? '',
    );
    _selectedCategory = widget.product?.category;
    _nonExpiringQuantity = widget.product?.nonExpiringQuantity ?? 0;
    _expiries = List.from(widget.product?.expiries ?? []);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final userId = _authService.getUserId();
    if (userId == null) return;

    setState(() => _isSaving = true);

    try {
      final productId =
          widget.product?.id ?? DateTime.now().millisecondsSinceEpoch;
      final product = Product(
        id: productId,
        name: _nameController.text,
        description: _descriptionController.text,
        userId: userId,
        expiries: _expiries,
        nonExpiringQuantity: _nonExpiringQuantity,
        category: _selectedCategory,
        isGlobal: widget.product?.isGlobal ?? false,
      );

      if (widget.product == null) {
        await _productService.addProduct(product);
        if (widget.initialCollectionId != null) {
          final collectionService = getIt<CollectionService>();
          await collectionService.addProductToCollection(
            widget.initialCollectionId!,
            productId,
          );
        }
      } else {
        await _productService.updateProduct(product);
      }

      if (mounted) {
        context.pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to save product: $e')));
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

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.product == null ? 'product.add'.tr() : 'product.edit'.tr(),
        ),
        actions: [
          if (_isSaving)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else
            IconButton(icon: const Icon(Icons.check), onPressed: _save),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _nameController,
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
              maxLines: 3,
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
              onChanged: (val) => setState(() => _selectedCategory = val),
            ),
            const SizedBox(height: 24),
            Text(
              'product.inventory'.tr(),
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            _buildQuantitySection(),
            const SizedBox(height: 24),
            _buildExpiriesSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildQuantitySection() {
    return ListTile(
      title: Text('product.non_expiring_quantity'.tr()),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.remove),
            onPressed: _nonExpiringQuantity > 0
                ? () => setState(() => _nonExpiringQuantity--)
                : null,
          ),
          Text(_nonExpiringQuantity.toString()),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => setState(() => _nonExpiringQuantity++),
          ),
        ],
      ),
    );
  }

  Widget _buildExpiriesSection() {
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
              icon: const Icon(Icons.add),
              label: Text('product.add_expiry'.tr()),
              onPressed: _addExpiry,
            ),
          ],
        ),
        ..._expiries.asMap().entries.map((entry) {
          final idx = entry.key;
          final expiry = entry.value;
          return ListTile(
            title: Text(DateFormat.yMMMd().format(expiry.expirationDate)),
            subtitle: Text(
              'product.quantity_units'.tr(args: [expiry.quantity.toString()]),
            ),
            trailing: IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: () => setState(() => _expiries.removeAt(idx)),
            ),
          );
        }),
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
      setState(() {
        _expiries.add(ExpiryEntry(quantity: 1, expirationDate: date));
      });
    }
  }
}
