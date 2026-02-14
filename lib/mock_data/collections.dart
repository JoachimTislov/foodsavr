/// Mock data for collections
/// Each item is a map that can be used to construct a Collection
class CollectionsData {
  static List<Map<String, dynamic>> getCollections() {
    return [
      {
        'id': '1',
        'name': 'My Inventory',
        'description': 'My personal food inventory',
        'type': 'inventory',
        'productIds': [1, 2, 3],
      },
      {
        'id': '2',
        'name': 'Shopping List',
        'description': 'Items to buy',
        'type': 'shoppingList',
        'productIds': [4, 5],
      },
      {
        'id': '3',
        'name': 'Favorites',
        'description': 'My favorite items',
        'type': 'favorites',
        'productIds': [6, 7],
      },
    ];
  }
}
