import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:watch_it/watch_it.dart';
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
    return showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: _CollectionFormSheet(type: type, collection: collection),
        ),
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

class _CollectionFormSheetState extends State<_CollectionFormSheet>
    with WatchItStatefulWidgetMixin {
  final _formKey = GlobalKey<FormState>();
  late final CollectionService _collectionService;
  late final IAuthService _authService;

  late TextEditingController _nameController;
  late TextEditingController _descriptionController;

  final _isSaving = ValueNotifier<bool>(false);

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
    _isSaving.dispose();
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

    _isSaving.value = true;

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
        _isSaving.value = false;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isSaving = watch(_isSaving).value;
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
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
              onPressed: isSaving ? null : _save,
              child: isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(
                      widget.collection != null
                          ? 'common.save'.tr()
                          : 'common.create'.tr(),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
