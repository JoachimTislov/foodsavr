import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../models/collection_model.dart';
import '../common/adaptive_sheet.dart';

class DeleteCollectionSheet extends StatefulWidget {
  final Collection collection;
  final int productCount;
  final List<Collection> destinations;

  const DeleteCollectionSheet._({
    required this.collection,
    required this.productCount,
    required this.destinations,
  });

  static Future<DeleteCollectionChoice?> show(
    BuildContext context, {
    required Collection collection,
    required int productCount,
    required List<Collection> destinations,
  }) => AdaptiveSheet.show(
    context,
    builder: (_) => DeleteCollectionSheet._(
      collection: collection,
      productCount: productCount,
      destinations: destinations,
    ),
  );

  @override
  State<DeleteCollectionSheet> createState() => _DeleteCollectionSheetState();
}

class _DeleteCollectionSheetState extends State<DeleteCollectionSheet> {
  String? _destinationId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasProducts = widget.productCount > 0;
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'collection.deleteTitle'.tr(
              namedArgs: {'name': widget.collection.name},
            ),
            style: theme.textTheme.headlineSmall,
          ),
          if (hasProducts) ...[
            const SizedBox(height: 12),
            Text(
              widget.destinations.isEmpty
                  ? 'collection.deleteWithoutDestination'.tr()
                  : 'collection.deleteWithDestination'.tr(),
            ),
          ],
          if (widget.destinations.isNotEmpty) ...[
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              isExpanded: true,
              decoration: InputDecoration(
                labelText: 'collection.moveDestination'.tr(),
              ),
              items: [
                for (final inventory in widget.destinations)
                  DropdownMenuItem(
                    value: inventory.id,
                    child: Text(
                      inventory.name,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: (id) => setState(() => _destinationId = id),
            ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: _destinationId == null
                  ? null
                  : () => Navigator.of(context).pop(
                      DeleteCollectionChoice(destinationId: _destinationId),
                    ),
              child: Text('collection.moveAndDelete'.tr()),
            ),
          ],
          const SizedBox(height: 8),
          FilledButton(
            onPressed: () =>
                Navigator.of(context).pop(const DeleteCollectionChoice()),
            style: FilledButton.styleFrom(
              backgroundColor: theme.colorScheme.error,
              foregroundColor: theme.colorScheme.onError,
            ),
            child: Text(
              hasProducts
                  ? 'collection.deleteWithProducts'.tr()
                  : 'common.delete'.tr(),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('common.cancel'.tr()),
          ),
        ],
      ),
    );
  }
}

class DeleteCollectionChoice {
  final String? destinationId;

  const DeleteCollectionChoice({this.destinationId});
}
