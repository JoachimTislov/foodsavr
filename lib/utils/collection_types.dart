/// Collection type enumeration
/// Only static collection types are supported: Inventory and Shopping List
enum CollectionType { inventory, shoppingList }

CollectionType collectionTypeFromJson(String json) {
  return CollectionType.values.firstWhere(
    (e) => e.name == json,
    orElse: () => CollectionType.inventory,
  );
}
