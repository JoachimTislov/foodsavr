/// Catalog of everyday grocery essentials seeded as global products.
///
/// The only source of the catalog: `scripts/seed_global_catalog.py` parses the
/// list below, so keep every entry a map of single-quoted string literals.
/// Barcodes are synthetic test data: sequential numbers in the Norwegian `70`
/// prefix range with valid EAN-13 check digits, not the GTINs of real items.
class GlobalProductsData {
  static List<Map<String, dynamic>> getProducts() {
    return [
      // Dairy and eggs
      {
        'id': 'global-milk-whole',
        'name': 'Whole Milk',
        'description': 'Fresh whole milk, 1 l',
        'category': 'dairy',
        'barcode': '7090000000011',
      },
      {
        'id': 'global-milk-semi-skimmed',
        'name': 'Semi-Skimmed Milk',
        'description': 'Fresh semi-skimmed milk, 1 l',
        'category': 'dairy',
        'barcode': '7090000000028',
      },
      {
        'id': 'global-butter-salted',
        'name': 'Salted Butter',
        'description': 'Salted dairy butter, 500 g',
        'category': 'dairy',
        'barcode': '7090000000035',
      },
      {
        'id': 'global-cheese-yellow',
        'name': 'Yellow Cheese',
        'description': 'Mild semi-hard cheese, 500 g',
        'category': 'dairy',
        'barcode': '7090000000042',
      },
      {
        'id': 'global-yogurt-natural',
        'name': 'Natural Yogurt',
        'description': 'Plain unsweetened yogurt, 500 g',
        'category': 'dairy',
        'barcode': '7090000000059',
      },
      {
        'id': 'global-eggs',
        'name': 'Eggs',
        'description': 'Free-range eggs, 12 pack',
        'category': 'dairy',
        'barcode': '7090000000066',
      },
      // Bakery
      {
        'id': 'global-bread-wholegrain',
        'name': 'Wholegrain Bread',
        'description': 'Sliced wholegrain loaf',
        'category': 'bakery',
        'barcode': '7090000000073',
      },
      {
        'id': 'global-crispbread',
        'name': 'Crispbread',
        'description': 'Rye crispbread',
        'category': 'bakery',
        'barcode': '7090000000080',
      },
      {
        'id': 'global-tortillas',
        'name': 'Tortillas',
        'description': 'Soft wheat tortillas, 8 pack',
        'category': 'bakery',
        'barcode': '7090000000097',
      },
      // Fruits
      {
        'id': 'global-apples',
        'name': 'Apples',
        'description': 'Fresh apples, 1 kg',
        'category': 'fruits',
        'barcode': '7090000000103',
      },
      {
        'id': 'global-bananas',
        'name': 'Bananas',
        'description': 'Fresh bananas, 1 kg',
        'category': 'fruits',
        'barcode': '7090000000110',
      },
      {
        'id': 'global-oranges',
        'name': 'Oranges',
        'description': 'Fresh oranges, 1 kg',
        'category': 'fruits',
        'barcode': '7090000000127',
      },
      // Vegetables, fresh and frozen
      {
        'id': 'global-potatoes',
        'name': 'Potatoes',
        'description': 'All-purpose potatoes, 2 kg',
        'category': 'vegetables',
        'barcode': '7090000000134',
      },
      {
        'id': 'global-carrots',
        'name': 'Carrots',
        'description': 'Fresh carrots, 1 kg',
        'category': 'vegetables',
        'barcode': '7090000000141',
      },
      {
        'id': 'global-onions',
        'name': 'Onions',
        'description': 'Yellow onions, 1 kg',
        'category': 'vegetables',
        'barcode': '7090000000158',
      },
      {
        'id': 'global-tomatoes',
        'name': 'Tomatoes',
        'description': 'Fresh tomatoes, 500 g',
        'category': 'vegetables',
        'barcode': '7090000000165',
      },
      {
        'id': 'global-cucumber',
        'name': 'Cucumber',
        'description': 'Fresh cucumber',
        'category': 'vegetables',
        'barcode': '7090000000172',
      },
      {
        'id': 'global-peas-frozen',
        'name': 'Frozen Peas',
        'description': 'Frozen green peas, 750 g',
        'category': 'vegetables',
        'barcode': '7090000000189',
      },
      // Pantry, canned goods and drinks
      {
        'id': 'global-pasta-spaghetti',
        'name': 'Pasta',
        'description': 'Italian spaghetti pasta, 500 g',
        'category': 'pantry',
        'barcode': '7090000000196',
      },
      {
        'id': 'global-rice-long-grain',
        'name': 'Rice',
        'description': 'Long grain white rice, 1 kg',
        'category': 'pantry',
        'barcode': '7090000000202',
      },
      {
        'id': 'global-flour-wheat',
        'name': 'Wheat Flour',
        'description': 'All-purpose wheat flour, 2 kg',
        'category': 'pantry',
        'barcode': '7090000000219',
      },
      {
        'id': 'global-sugar',
        'name': 'Sugar',
        'description': 'Granulated white sugar, 1 kg',
        'category': 'pantry',
        'barcode': '7090000000226',
      },
      {
        'id': 'global-oats',
        'name': 'Rolled Oats',
        'description': 'Wholegrain rolled oats, 1 kg',
        'category': 'pantry',
        'barcode': '7090000000233',
      },
      {
        'id': 'global-oil-olive',
        'name': 'Olive Oil',
        'description': 'Extra virgin olive oil, 500 ml',
        'category': 'pantry',
        'barcode': '7090000000240',
      },
      {
        'id': 'global-tomato-sauce',
        'name': 'Tomato Sauce',
        'description': 'Classic marinara sauce, 400 g',
        'category': 'pantry',
        'barcode': '7090000000257',
      },
      {
        'id': 'global-tomatoes-canned',
        'name': 'Canned Tomatoes',
        'description': 'Chopped tomatoes, 400 g can',
        'category': 'pantry',
        'barcode': '7090000000264',
      },
      {
        'id': 'global-beans-black',
        'name': 'Black Beans',
        'description': 'Canned black beans, 400 g',
        'category': 'pantry',
        'barcode': '7090000000271',
      },
      {
        'id': 'global-mackerel-tomato',
        'name': 'Mackerel in Tomato Sauce',
        'description': 'Canned mackerel fillets, 170 g',
        'category': 'pantry',
        'barcode': '7090000000288',
      },
      {
        'id': 'global-honey',
        'name': 'Honey',
        'description': 'Pure organic honey, 350 g',
        'category': 'pantry',
        'barcode': '7090000000295',
      },
      {
        'id': 'global-coffee-ground',
        'name': 'Ground Coffee',
        'description': 'Filter-ground coffee, 250 g',
        'category': 'pantry',
        'barcode': '7090000000301',
      },
    ];
  }
}
