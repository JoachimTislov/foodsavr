/// Mock data for global products
/// Each item is a map that can be used to construct a Product
class GlobalProductsData {
  static List<Map<String, dynamic>> getProducts() {
    return [
      {
        'id': 1001,
        'name': 'Pasta',
        'description': 'Italian spaghetti pasta',
        'category': 'Pantry',
      },
      {
        'id': 1002,
        'name': 'Rice',
        'description': 'Long grain white rice',
        'category': 'Pantry',
      },
      {
        'id': 1003,
        'name': 'Olive Oil',
        'description': 'Extra virgin olive oil',
        'category': 'Pantry',
      },
      {
        'id': 1004,
        'name': 'Tomato Sauce',
        'description': 'Classic marinara sauce',
        'category': 'Pantry',
      },
      {
        'id': 1005,
        'name': 'Black Beans',
        'description': 'Canned black beans',
        'category': 'Pantry',
      },
      {
        'id': 1006,
        'name': 'Honey',
        'description': 'Pure organic honey',
        'category': 'Pantry',
      },
    ];
  }
}
