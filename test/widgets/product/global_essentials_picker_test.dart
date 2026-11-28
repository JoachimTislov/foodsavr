import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foodsavr/models/product_model.dart';
import 'package:foodsavr/services/product_service.dart';
import 'package:foodsavr/widgets/product/global_essentials_picker.dart';
import 'package:foodsavr/widgets/product/product_icon.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/test_translation_loader.dart';

class _MockProductService extends Mock implements ProductService {}

void main() {
  late TestTranslationLoader translations;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    translations = TestTranslationLoader();
    SharedPreferences.setMockInitialValues({});
    EasyLocalization.logger.enableLevels = [];
    EasyLocalization.logger.enableBuildModes = [];
    await EasyLocalization.ensureInitialized();
  });

  const essentials = [
    Product(
      id: 'global-milk',
      name: 'Whole Milk',
      description: 'Fresh whole milk, 1 l',
      userId: 'system',
      category: 'dairy',
      barcode: '7090000000011',
      isGlobal: true,
    ),
    Product(
      id: 'global-apples',
      name: 'Apples',
      description: 'Fresh apples, 1 kg',
      userId: 'system',
      category: 'fruits',
      barcode: '7090000000103',
      isGlobal: true,
    ),
    Product(
      id: 'global-bread',
      name: 'Wholegrain Bread',
      description: 'Sliced loaf',
      userId: 'system',
      category: 'bakery',
      isGlobal: true,
    ),
  ];

  Future<void> pumpPicker(WidgetTester tester, Widget child) async {
    await tester.pumpWidget(
      EasyLocalization(
        supportedLocales: const [Locale('en')],
        startLocale: const Locale('en'),
        saveLocale: false,
        path: 'assets/translations',
        assetLoader: translations,
        child: Builder(
          builder: (context) => MaterialApp(
            localizationsDelegates: context.localizationDelegates,
            supportedLocales: context.supportedLocales,
            locale: context.locale,
            home: Scaffold(
              body: SizedBox(width: 420, height: 500, child: child),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'loads essentials via ProductService and renders icons & barcodes',
    (tester) async {
      final service = _MockProductService();
      when(service.getAllProducts).thenAnswer((_) async => essentials);

      Product? picked;
      await pumpPicker(
        tester,
        GlobalEssentialsPicker(
          productService: service,
          onSelect: (p) => picked = p,
        ),
      );

      expect(find.text('Whole Milk'), findsOneWidget);
      expect(find.text('Apples'), findsOneWidget);
      expect(find.text('7090000000011'), findsOneWidget);
      expect(find.byType(ProductIcon), findsNWidgets(3));

      await tester.tap(find.text('Whole Milk'));
      await tester.pump();
      expect(picked?.id, 'global-milk');
    },
  );

  testWidgets('filters essentials by search query and category chips', (
    tester,
  ) async {
    await pumpPicker(
      tester,
      GlobalEssentialsPicker(products: essentials, onSelect: (_) {}),
    );

    // Filter by category chip.
    await tester.tap(find.widgetWithText(FilterChip, 'Fruits'));
    await tester.pumpAndSettle();
    expect(find.text('Apples'), findsOneWidget);
    expect(find.text('Whole Milk'), findsNothing);

    // Reset to All categories and search by barcode/name.
    await tester.tap(find.widgetWithText(FilterChip, 'All categories'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'bread');
    await tester.pumpAndSettle();
    expect(find.text('Wholegrain Bread'), findsOneWidget);
    expect(find.text('Apples'), findsNothing);

    // Search with no matches shows empty message.
    await tester.enterText(find.byType(TextField), 'zzzz-unknown');
    await tester.pumpAndSettle();
    expect(find.text('No matching essentials'), findsOneWidget);
  });

  testWidgets('supports quick-add action button per essential', (tester) async {
    Product? quickAdded;
    await pumpPicker(
      tester,
      GlobalEssentialsPicker(
        products: [essentials.first],
        onSelect: (_) {},
        onQuickAdd: (p) => quickAdded = p,
      ),
    );

    await tester.tap(find.byTooltip('Quick add'));
    await tester.pump();
    expect(quickAdded?.id, 'global-milk');
  });
}
