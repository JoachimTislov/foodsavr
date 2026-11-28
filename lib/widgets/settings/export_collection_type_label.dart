import 'package:easy_localization/easy_localization.dart';

import '../../utils/collection_types.dart';

String exportCollectionTypeLabel(CollectionType type) => switch (type) {
  CollectionType.inventory => 'collection.type_inventory'.tr(),
  CollectionType.shoppingList => 'dashboard.shoppingList'.tr(),
};
