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

  static Future<bool?> show(BuildContext context,
      {required CollectionType type, Collection? collection}) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) =>
          _CollectionFormSheet(type: type, collection: collection),
    );
  }

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}

class _CollectionFormSheet extends StatefulWidget with WatchItStatefulWidgetMixin {
  final CollectionType type;
  final Collection? collection;

  const _CollectionFormSheet({required this.type, this.collection});

  @override
  State<_CollectionFormSheet> createState() => _CollectionFormSheetState();
}

class _CollectionFormSheetState extends State<_CollectionFormSheet> with WatchItMixin {
  final _formKey = GlobalKey<FormState>();
  late final CollectionService _collectionService;
  late final IAuthService _authService;

  late TextEditingController _nameController;
  final _isSaving = ValueNotifier<bool>(false);

  @override
  void initState() {
    super.initState();
    _collectionService = getIt<CollectionService>();
    _authService = getIt<IAuthService>();
    _nameController =
        TextEditingController(text: widget.collection?.name ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _isSaving.dispose();
    super.dispose();
  }

  String _title() {
    if (widget.collection != null) {
      return 'collection.editTitle'.tr();
    }
    return widget.type == CollectionType.inventory
        ? 'collection.createInventoryTitle'.tr()
        : 'collection.createShoppingListTitle'.tr();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final userId = _authService.getUserId();
    if (userId == null) return;

    _isSaving.value = true;
    try {
      if (widget.collection != null) {
        final updated = widget.collection!.copyWith(
          name: _nameController.text,
        );
        await _collectionService.updateCollection(updated);
      } else {
        final collection = Collection(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          name: _nameController.text,
          userId: userId,
          type: widget.type,
          productIds: [],
        );
        await _collectionService.addCollection(collection);
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

  @override
  Widget build(BuildContext context) {
    final isSaving = watch(_isSaving).value;

    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _title(),
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Form(
              key: _formKey,
              child: TextFormField(
                controller: _nameController,
                autofocus: true,
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
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: isSaving ? null : _save,
              child: isSaving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
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
