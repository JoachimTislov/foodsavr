import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../interfaces/i_auth_service.dart';
import '../models/collection_model.dart';
import '../routes/page_trail.dart';
import '../service_locator.dart';
import '../services/collection_service.dart';
import '../views/collection_detail_view.dart';
import 'collection_types.dart';
import 'user_error.dart';

/// Creates a collection under a unique default name and opens it with its
/// title ready to be renamed.
class CollectionCreateFlow {
  const CollectionCreateFlow._();

  /// Returns the created collection once its page was closed, or null when it
  /// could not be created.
  static Future<Collection?> run(
    BuildContext context,
    CollectionType type,
  ) async {
    final userId = getIt<IAuthService>().getUserId();
    if (userId == null) return null;
    final baseName = type == CollectionType.shoppingList
        ? 'collection.defaultShoppingListName'.tr()
        : 'collection.defaultInventoryName'.tr();
    final Collection created;
    try {
      created = await getIt<CollectionService>().createWithDefaultName(
        userId,
        type,
        baseName: baseName,
      );
    } catch (e, stack) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              userErrorMessage(e, 'collection.saveError'.tr(), stack),
            ),
          ),
        );
      }
      return null;
    }
    if (!context.mounted) return created;
    await PageTrail.push<void>(
      context,
      label: created.name,
      builder: (_) =>
          CollectionDetailView(collection: created, startEditingTitle: true),
    );
    return created;
  }
}
