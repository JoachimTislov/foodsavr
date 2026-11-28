import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foodsavr/constants/product_categories.dart';
import 'package:foodsavr/models/product_model.dart';
import 'package:foodsavr/utils/app_theme.dart';
import 'package:foodsavr/widgets/product/product_icon.dart';

void main() {
  group('ProductIcon.resolveIcon', () {
    test('matches common English and Norwegian grocery keywords', () {
      final cases = <(String, IconData)>[
        ('Whole Milk', Icons.local_drink),
        ('Lettmelk', Icons.local_drink),
        ('Yellow Cheese', Icons.tapas),
        ('Gulost', Icons.tapas),
        ('Free-range Eggs', Icons.egg),
        ('Natural Yogurt', Icons.icecream),
        ('Yoghurt', Icons.icecream),
        ('Salted Butter', Icons.breakfast_dining),
        ('Smør', Icons.breakfast_dining),
        ('Wholegrain Bread', Icons.bakery_dining),
        ('Grovbrød', Icons.bakery_dining),
        ('Apples', Icons.apple),
        ('Epler', Icons.apple),
        ('Bananas', Icons.spa),
        ('Jordbær', Icons.spa),
        ('Tomatoes', Icons.grass),
        ('Gulrot', Icons.grass),
        ('Rødløk', Icons.grass),
        ('Poteter', Icons.grass),
        ('Salat', Icons.eco),
        ('Ground Coffee', Icons.coffee),
        ('Kaffe', Icons.coffee),
        ('Pasta', Icons.ramen_dining),
        ('Rice', Icons.rice_bowl),
        ('Ris', Icons.rice_bowl),
        ('Olive Oil', Icons.opacity),
        ('Olivenolje', Icons.opacity),
        ('Tomato Soup', Icons.soup_kitchen),
        ('Tomatsuppe', Icons.soup_kitchen),
        ('Sparkling Water', Icons.water_drop),
        ('Vann', Icons.water_drop),
        ('Orange Juice', Icons.local_drink),
      ];

      for (final (name, expectedIcon) in cases) {
        expect(
          ProductIcon.resolveIcon(name),
          expectedIcon,
          reason: 'Expected "$name" to resolve to $expectedIcon',
        );
      }
    });

    test('falls back to ProductCategory.getIcon when no keyword matches', () {
      expect(
        ProductIcon.resolveIcon('Mystery Item', category: 'fruits'),
        ProductCategory.getIcon('fruits'),
      );
      expect(
        ProductIcon.resolveIcon('Mystery Item', category: 'pantry'),
        ProductCategory.getIcon('pantry'),
      );
      expect(ProductIcon.resolveIcon('Mystery Item'), Icons.shopping_bag);
    });
  });

  group('ProductIcon widget', () {
    for (final brightness in Brightness.values) {
      testWidgets('renders category-tinted badge in ${brightness.name} theme', (
        tester,
      ) async {
        const product = Product(
          id: 'p1',
          name: 'Whole Milk',
          description: '',
          userId: 'u1',
          category: 'dairy',
        );

        await tester.pumpWidget(
          MaterialApp(
            theme: brightness == Brightness.light
                ? AppTheme.lightTheme
                : AppTheme.darkTheme,
            home: Scaffold(
              body: Center(child: ProductIcon.fromProduct(product)),
            ),
          ),
        );

        final icon = tester.widget<Icon>(find.byType(Icon));
        expect(icon.icon, Icons.local_drink);
        final container = tester.widget<Container>(find.byType(Container));
        final decoration = container.decoration! as BoxDecoration;
        expect(decoration.color, isNotNull);
        expect(icon.color, isNot(decoration.color));
      });
    }

    testWidgets('excludes decorative icon from semantics tree', (tester) async {
      final semantics = tester.ensureSemantics();
      try {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: ProductIcon(name: 'Apples', category: 'fruits'),
            ),
          ),
        );

        expect(
          find.descendant(
            of: find.byType(ProductIcon),
            matching: find.byType(ExcludeSemantics),
          ),
          findsAtLeastNWidgets(1),
        );
        expect(tester.getSemantics(find.byType(ProductIcon)).label, isEmpty);
      } finally {
        semantics.dispose();
      }
    });
  });
}
