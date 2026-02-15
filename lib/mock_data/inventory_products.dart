/// Mock data for inventory products
/// Each item is a map that can be used to construct a Product
class InventoryProductsData {
  static List<Map<String, dynamic>> getProducts() {
    return [
      {
        'id': 1,
        'name': 'Apple',
        'description': 'A crisp and juicy apple.',
        'expirationDays': 5,
        'quantity': 6,
        'category': 'Fruits',
      },
      {
        'id': 2,
        'name': 'Banana',
        'description': 'A ripe and sweet banana.',
        'expirationDays': 2,
        'quantity': 4,
        'category': 'Fruits',
      },
      {
        'id': 3,
        'name': 'Carrot',
        'description': 'An orange carrot.',
        'expirationDays': 10,
        'quantity': 8,
        'category': 'Vegetables',
      },
      {
        'id': 4,
        'name': 'Milk',
        'description': 'Organic whole milk',
        'expirationDays': 1,
        'quantity': 1,
        'category': 'Dairy',
      },
      {
        'id': 5,
        'name': 'Bread',
        'description': 'Whole wheat bread',
        'expirationDays': 3,
        'quantity': 1,
        'category': 'Bakery',
      },
      {
        'id': 6,
        'name': 'Eggs',
        'description': 'Farm fresh eggs',
        'expirationDays': 14,
        'quantity': 12,
        'category': 'Dairy',
      },
      {
        'id': 7,
        'name': 'Cheese',
        'description': 'Aged cheddar cheese',
        'expirationDays': 20,
        'quantity': 1,
        'category': 'Dairy',
      },
      {
        'id': 8,
        'name': 'Tomato',
        'description': 'Fresh red tomatoes',
        'expirationDays': 4,
        'quantity': 5,
        'category': 'Vegetables',
      },
    ];
  }
}
