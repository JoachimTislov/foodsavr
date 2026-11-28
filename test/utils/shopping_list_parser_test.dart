import 'package:flutter_test/flutter_test.dart';
import 'package:foodsavr/utils/shopping_list_parser.dart';

void main() {
  group('ShoppingListParser.parse', () {
    test('returns empty list for blank or whitespace-only input', () {
      expect(ShoppingListParser.parse(''), isEmpty);
      expect(ShoppingListParser.parse('   \n\t\r\n  '), isEmpty);
      expect(ShoppingListParser.parse(',,, ; ; \n'), isEmpty);
    });

    test('parses multi-line, comma, and semicolon-separated lists', () {
      const input = 'Milk\nBread, Eggs\nApples; Carrots';
      final items = ShoppingListParser.parse(input);
      expect(items, [
        const ParsedShoppingItem(name: 'Milk', quantity: 1, category: 'dairy'),
        const ParsedShoppingItem(
          name: 'Bread',
          quantity: 1,
          category: 'bakery',
        ),
        const ParsedShoppingItem(name: 'Eggs', quantity: 1, category: 'dairy'),
        const ParsedShoppingItem(
          name: 'Apples',
          quantity: 1,
          category: 'fruits',
        ),
        const ParsedShoppingItem(
          name: 'Carrots',
          quantity: 1,
          category: 'vegetables',
        ),
      ]);
    });

    test('strips bullet points and numbered prefixes', () {
      const input = '''
- Milk
* Bread
• Eggs
1. Apples
2) Bananas
10. Coffee
''';
      final items = ShoppingListParser.parse(input);
      expect(items.map((e) => e.name).toList(), [
        'Milk',
        'Bread',
        'Eggs',
        'Apples',
        'Bananas',
        'Coffee',
      ]);
    });

    test('handles markdown and unicode checkboxes and skips checked items', () {
      const input = '''
- [ ] Milk
- [x] Butter
[X] Cheese
☐ Bread
☑ Yogurt
✅ Coffee
[ ] Eggs
''';
      final defaultItems = ShoppingListParser.parse(input);
      expect(defaultItems.map((e) => e.name).toList(), [
        'Milk',
        'Bread',
        'Eggs',
      ]);

      final allItems = ShoppingListParser.parse(input, skipChecked: false);
      expect(allItems.map((e) => e.name).toList(), [
        'Milk',
        'Butter',
        'Cheese',
        'Bread',
        'Yogurt',
        'Coffee',
        'Eggs',
      ]);
    });

    test('parses common prefix and suffix quantity patterns', () {
      const input = '''
2x Milk
2 x Bread
3 apples
Eggs x6
Butter (2)
Coffee (x3)
4 stk epler
''';
      final items = ShoppingListParser.parse(input);
      expect(items, [
        const ParsedShoppingItem(name: 'Milk', quantity: 2, category: 'dairy'),
        const ParsedShoppingItem(
          name: 'Bread',
          quantity: 2,
          category: 'bakery',
        ),
        const ParsedShoppingItem(
          name: 'apples',
          quantity: 3,
          category: 'fruits',
        ),
        const ParsedShoppingItem(name: 'Eggs', quantity: 6, category: 'dairy'),
        const ParsedShoppingItem(
          name: 'Butter',
          quantity: 2,
          category: 'dairy',
        ),
        const ParsedShoppingItem(
          name: 'Coffee',
          quantity: 3,
          category: 'pantry',
        ),
        const ParsedShoppingItem(
          name: 'epler',
          quantity: 4,
          category: 'fruits',
        ),
      ]);
    });

    test(
      'preserves measurement units instead of treating weights as counts',
      () {
        final items = ShoppingListParser.parse(
          '500 g butter\n2 l milk\n1 kg potatoes',
        );
        expect(items, [
          const ParsedShoppingItem(
            name: '500 g butter',
            quantity: 1,
            category: 'dairy',
          ),
          const ParsedShoppingItem(
            name: '2 l milk',
            quantity: 1,
            category: 'dairy',
          ),
          const ParsedShoppingItem(
            name: '1 kg potatoes',
            quantity: 1,
            category: 'vegetables',
          ),
        ]);
      },
    );

    test('clamps zero quantities to 1', () {
      final items = ShoppingListParser.parse('0x Milk, 0 apples');
      expect(items.map((e) => e.quantity).toList(), [1, 1]);
    });

    test('deduplicates case-insensitively and sums quantities in order', () {
      const input = 'Milk\n2x bread, milk x3\nBREAD (1)\n- Eggs';
      final items = ShoppingListParser.parse(input);
      expect(items, [
        const ParsedShoppingItem(name: 'Milk', quantity: 4, category: 'dairy'),
        const ParsedShoppingItem(
          name: 'bread',
          quantity: 3,
          category: 'bakery',
        ),
        const ParsedShoppingItem(name: 'Eggs', quantity: 1, category: 'dairy'),
      ]);
    });

    test('infers categories for English and Norwegian grocery words', () {
      final cases = <(String, String?)>[
        ('Whole Milk', 'dairy'),
        ('Helmelk', 'dairy'),
        ('Gulost', 'dairy'),
        ('Brunost', 'dairy'),
        ('Smør', 'dairy'),
        ('Yoghurt', 'dairy'),
        ('Knekkebrød', 'bakery'),
        ('Grovbrød', 'bakery'),
        ('Toast', 'bakery'),
        ('Bananer', 'fruits'),
        ('Jordbær', 'fruits'),
        ('Appelsiner', 'fruits'),
        ('Gulrøtter', 'vegetables'),
        ('Rødløk', 'vegetables'),
        ('Poteter', 'vegetables'),
        ('Eggplant', 'vegetables'),
        ('Tomato Sauce', 'pantry'),
        ('Canned Tomatoes', 'pantry'),
        ('Olivenolje', 'pantry'),
        ('Havregryn', 'pantry'),
        ('Kaffe', 'pantry'),
        ('Pasta', 'pantry'),
        ('Ris', 'pantry'),
        ('Suppe', 'pantry'),
        ('Mystery Widget', null),
      ];

      for (final (name, expectedCategory) in cases) {
        final parsed = ShoppingListParser.parse(name).single;
        expect(
          parsed.category,
          expectedCategory,
          reason: 'Expected "$name" -> $expectedCategory',
        );
      }
    });
  });
}
