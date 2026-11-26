import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foodsavr/constants/product_categories.dart';
import 'package:foodsavr/models/product_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/test_translation_loader.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    EasyLocalization.logger.enableLevels = [];
    await EasyLocalization.ensureInitialized();
  });

  test('normalizes legacy English names to stable keys', () {
    expect(ProductCategory.normalize('Dairy'), 'dairy');
    expect(ProductCategory.normalize('dairy'), 'dairy');
    expect(ProductCategory.normalize('Drinks'), 'Drinks');
    expect(ProductCategory.normalize(''), isNull);
    expect(ProductCategory.normalize(null), isNull);
  });

  test('migrates a stored English category when read', () {
    final product = Product.fromJson({
      'id': 'p',
      'name': 'Milk',
      'description': '',
      'userId': 'u',
      'category': 'Dairy',
    });
    expect(product.category, 'dairy');
    expect(ProductCategory.getIcon(product.category), Icons.egg);
  });

  for (final (language, expected) in [('en', 'Dairy'), ('nb', 'Meieri')]) {
    testWidgets('renders a category key in $language', (tester) async {
      await tester.runAsync(() async {
        await tester.pumpWidget(
          EasyLocalization(
            supportedLocales: [Locale(language)],
            path: 'assets/translations',
            assetLoader: TestTranslationLoader(language),
            child: Builder(
              builder: (context) => MaterialApp(
                localizationsDelegates: context.localizationDelegates,
                supportedLocales: context.supportedLocales,
                locale: context.locale,
                home: Builder(
                  builder: (context) => Text(ProductCategory.label('dairy')),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
      });
      await tester.pump();

      expect(find.text(expected), findsOneWidget);
      expect(ProductCategory.label('Drinks'), 'Drinks');
    });
  }
}
