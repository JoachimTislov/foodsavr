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

  static Future<bool?> show(
    BuildContext context, {
    required CollectionType type,
    Collection? collection,
  }) {
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

class _CollectionFormSheet extends WatchingWidget {
  final CollectionType type;
  final Collection? collection;

  const _CollectionFormSheet({required this.type, this.collection});

  @override
  Widget build(BuildContext context) {
    final collectionService = getIt<CollectionService>();
    final authService = getIt<IAuthService>();

    final nameController = createOnce(
      () => TextEditingController(text: collection?.name ?? ''),
    );
    final isSaving = createOnce(() => ValueNotifier<bool>(false));
    final formKey = createOnce(() => GlobalKey<FormState>());

    final saving = watch(isSaving).value;

    String title() {
      if (collection != null) {
        return 'collection.editTitle'.tr();
      }
      return type == CollectionType.inventory
          ? 'collection.createInventoryTitle'.tr()
          : 'collection.createShoppingListTitle'.tr();
    }

    Future<void> save() async {
      if (!formKey.currentState!.validate()) return;

      final userId = authService.getUserId();
      if (userId == null) return;

      isSaving.value = true;
      try {
        if (collection != null) {
          final updated = collection!.copyWith(name: nameController.text);
          await collectionService.updateCollection(updated);
        } else {
          final newCollection = Collection(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            name: nameController.text,
            userId: userId,
            type: type,
            productIds: [],
          );
          await collectionService.addCollection(newCollection);
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
              title(),
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Form(
              key: formKey,
              child: TextFormField(
                controller: nameController,
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
              onPressed: saving ? null : save,
              child: saving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(
                      collection != null
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
