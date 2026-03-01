import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import '../models/collection_model.dart';
import '../service_locator.dart';
import '../services/collection_service.dart';
import '../interfaces/i_auth_service.dart';
import '../utils/collection_types.dart';

class CollectionFormView extends StatelessWidget {
  final CollectionType type;
  final Collection? collection;

  const CollectionFormView({super.key, required this.type, this.collection});

  /// Shows the collection form as a modal bottom sheet.
  /// Returns `true` if a collection was saved.
  static Future<bool?> show(
    BuildContext context, {
    required CollectionType type,
    Collection? collection,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: _CollectionFormSheet(type: type, collection: collection),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}

class _CollectionFormSheet extends StatefulWidget {
  final CollectionType type;
  final Collection? collection;

  const _CollectionFormSheet({required this.type, this.collection});

  @override
  State<_CollectionFormSheet> createState() => _CollectionFormSheetState();
}

class _CollectionFormSheetState extends State<_CollectionFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final CollectionService _collectionService;
  late final IAuthService _authService;

  late TextEditingController _nameController;
  late TextEditingController _descriptionController;

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _collectionService = getIt<CollectionService>();
    _authService = getIt<IAuthService>();

    _nameController = TextEditingController(
      text: widget.collection?.name ?? '',
    );
    _descriptionController = TextEditingController(
      text: widget.collection?.description ?? '',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  String _title() {
    if (widget.collection != null) {
      return widget.type == CollectionType.inventory
          ? 'collection.edit_inventory'.tr()
          : 'collection.edit_shopping_list'.tr();
    }
    return widget.type == CollectionType.inventory
        ? 'collection.add_inventory'.tr()
        : 'collection.add_shopping_list'.tr();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final userId = _authService.getUserId();
    if (userId == null) return;

    setState(() => _isSaving = true);

    try {
      final collection = Collection(
        id: widget.collection?.id ?? '',
        name: _nameController.text,
        description: _descriptionController.text,
        userId: userId,
        type: widget.type,
        productIds: widget.collection?.productIds ?? [],
      );

      if (widget.collection == null) {
        await _collectionService.addCollection(collection);
      } else {
        await _collectionService.updateCollection(collection);
      }

      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save collection: $e')),
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
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 32,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _title(),
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _nameController,
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'collection.name'.tr(),
                border: const OutlineInputBorder(),
              ),
              validator: (value) => value == null || value.isEmpty
                  ? 'collection.name_required'.tr()
                  : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _descriptionController,
              decoration: InputDecoration(
                labelText: 'collection.description'.tr(),
                border: const OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _isSaving ? null : _save,
              child: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text('common.save'.tr()),
            ),
          ],
        ),
      ),
    );
  }
}
