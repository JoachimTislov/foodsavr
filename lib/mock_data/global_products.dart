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
        'name': 'Helmelk',
        'description': 'Fersk helmelk, 1 l',
        'category': 'dairy',
        'barcode': '7090000000011',
      },
      {
        'id': 'global-milk-semi-skimmed',
        'name': 'Lettmelk',
        'description': 'Fersk lettmelk, 1 l',
        'category': 'dairy',
        'barcode': '7090000000028',
      },
      {
        'id': 'global-butter-salted',
        'name': 'Meierismør',
        'description': 'Saltet meierismør, 500 g',
        'category': 'dairy',
        'barcode': '7090000000035',
      },
      {
        'id': 'global-cheese-yellow',
        'name': 'Gulost',
        'description': 'Mild gulost, 500 g',
        'category': 'dairy',
        'barcode': '7090000000042',
      },
      {
        'id': 'global-yogurt-natural',
        'name': 'Yoghurt naturell',
        'description': 'Usøtet yoghurt naturell, 500 g',
        'category': 'dairy',
        'barcode': '7090000000059',
      },
      {
        'id': 'global-eggs',
        'name': 'Egg',
        'description': 'Frittgående egg, 12-pakning',
        'category': 'dairy',
        'barcode': '7090000000066',
      },
      // Bakery
      {
        'id': 'global-bread-wholegrain',
        'name': 'Grovbrød',
        'description': 'Oppskåret grovbrød',
        'category': 'bakery',
        'barcode': '7090000000073',
      },
      {
        'id': 'global-crispbread',
        'name': 'Knekkebrød',
        'description': 'Grovt rugknekkebrød',
        'category': 'bakery',
        'barcode': '7090000000080',
      },
      {
        'id': 'global-tortillas',
        'name': 'Tortillalefser',
        'description': 'Myke hvetetortillas, 8-pakning',
        'category': 'bakery',
        'barcode': '7090000000097',
      },
      // Fruits
      {
        'id': 'global-apples',
        'name': 'Epler',
        'description': 'Friske epler, 1 kg',
        'category': 'fruits',
        'barcode': '7090000000103',
      },
      {
        'id': 'global-bananas',
        'name': 'Bananer',
        'description': 'Friske bananer, 1 kg',
        'category': 'fruits',
        'barcode': '7090000000110',
      },
      {
        'id': 'global-oranges',
        'name': 'Appelsiner',
        'description': 'Friske appelsiner, 1 kg',
        'category': 'fruits',
        'barcode': '7090000000127',
      },
      // Vegetables, fresh and frozen
      {
        'id': 'global-potatoes',
        'name': 'Poteter',
        'description': 'Kokefaste poteter, 2 kg',
        'category': 'vegetables',
        'barcode': '7090000000134',
      },
      {
        'id': 'global-carrots',
        'name': 'Gulrøtter',
        'description': 'Friske gulrøtter, 1 kg',
        'category': 'vegetables',
        'barcode': '7090000000141',
      },
      {
        'id': 'global-onions',
        'name': 'Gul løk',
        'description': 'Gul løk, 1 kg',
        'category': 'vegetables',
        'barcode': '7090000000158',
      },
      {
        'id': 'global-tomatoes',
        'name': 'Tomater',
        'description': 'Friske tomater, 500 g',
        'category': 'vegetables',
        'barcode': '7090000000165',
      },
      {
        'id': 'global-cucumber',
        'name': 'Agurk',
        'description': 'Frisk slangeagurk',
        'category': 'vegetables',
        'barcode': '7090000000172',
      },
      {
        'id': 'global-peas-frozen',
        'name': 'Frosne erter',
        'description': 'Frosne grønne erter, 750 g',
        'category': 'vegetables',
        'barcode': '7090000000189',
      },
      // Pantry, canned goods and drinks
      {
        'id': 'global-pasta-spaghetti',
        'name': 'Spaghetti',
        'description': 'Italiensk spaghetti, 500 g',
        'category': 'pantry',
        'barcode': '7090000000196',
      },
      {
        'id': 'global-rice-long-grain',
        'name': 'Ris',
        'description': 'Langkornet hvit ris, 1 kg',
        'category': 'pantry',
        'barcode': '7090000000202',
      },
      {
        'id': 'global-flour-wheat',
        'name': 'Hvetemel',
        'description': 'Siktet hvetemel, 2 kg',
        'category': 'pantry',
        'barcode': '7090000000219',
      },
      {
        'id': 'global-sugar',
        'name': 'Sukker',
        'description': 'Hvitt sukker, 1 kg',
        'category': 'pantry',
        'barcode': '7090000000226',
      },
      {
        'id': 'global-oats',
        'name': 'Havregryn',
        'description': 'Store havregryn, 1 kg',
        'category': 'pantry',
        'barcode': '7090000000233',
      },
      {
        'id': 'global-oil-olive',
        'name': 'Olivenolje',
        'description': 'Extra virgin olivenolje, 500 ml',
        'category': 'pantry',
        'barcode': '7090000000240',
      },
      {
        'id': 'global-tomato-sauce',
        'name': 'Tomatsaus',
        'description': 'Klassisk tomatsaus, 400 g',
        'category': 'pantry',
        'barcode': '7090000000257',
      },
      {
        'id': 'global-tomatoes-canned',
        'name': 'Hakkede tomater',
        'description': 'Hermetiske hakkede tomater, 400 g',
        'category': 'pantry',
        'barcode': '7090000000264',
      },
      {
        'id': 'global-beans-black',
        'name': 'Svarte bønner',
        'description': 'Hermetiske svarte bønner, 400 g',
        'category': 'pantry',
        'barcode': '7090000000271',
      },
      {
        'id': 'global-mackerel-tomato',
        'name': 'Makrell i tomat',
        'description': 'Makrellfilet i tomatsaus, 170 g',
        'category': 'pantry',
        'barcode': '7090000000288',
      },
      {
        'id': 'global-honey',
        'name': 'Honning',
        'description': 'Økologisk blomsterhonning, 350 g',
        'category': 'pantry',
        'barcode': '7090000000295',
      },
      {
        'id': 'global-coffee-ground',
        'name': 'Filterkaffe',
        'description': 'Filterkaffe, 250 g',
        'category': 'pantry',
        'barcode': '7090000000301',
      },
    ];
  }
}
