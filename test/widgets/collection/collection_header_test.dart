import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foodsavr/models/collection_model.dart';
import 'package:foodsavr/utils/collection_types.dart';
import 'package:foodsavr/widgets/collection/collection_card.dart';
import 'package:foodsavr/widgets/collection/collection_header.dart';
import 'package:foodsavr/widgets/collection/collection_kickstart_card.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/test_translation_loader.dart';

const _collection = Collection(
  id: 'c',
  name: 'Pantry',
  userId: 'user',
  type: CollectionType.inventory,
  productIds: [],
);

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    EasyLocalization.logger.enableLevels = [];
    await EasyLocalization.ensureInitialized();
  });

  Future<void> pump(WidgetTester tester, Widget child) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      EasyLocalization(
        supportedLocales: const [Locale('en')],
        startLocale: const Locale('en'),
        saveLocale: false,
        path: 'assets/translations',
        assetLoader: TestTranslationLoader(),
        child: Builder(
          builder: (context) => MaterialApp(
            localizationsDelegates: context.localizationDelegates,
            supportedLocales: context.supportedLocales,
            locale: context.locale,
            home: Scaffold(body: child),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('CollectionHeader', () {
    late List<String> renamed;

    Future<void> pumpHeader(
      WidgetTester tester, {
      bool startEditing = false,
    }) async {
      renamed = [];
      await pump(
        tester,
        CollectionHeader(
          collection: _collection,
          productCount: 3,
          startEditing: startEditing,
          onRename: (name) async => renamed.add(name),
          onAdd: () {},
          onDelete: () {},
        ),
      );
    }

    testWidgets('tapping the title edits it and Enter saves', (tester) async {
      await pumpHeader(tester);
      expect(find.byType(TextField), findsNothing);

      await tester.tap(find.text('Pantry'));
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsOneWidget);

      await tester.enterText(find.byType(TextField), '  Cellar ');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(renamed, ['Cellar']);
      expect(find.byType(TextField), findsNothing);
    });

    testWidgets('Escape cancels without saving', (tester) async {
      await pumpHeader(tester);
      await tester.tap(find.text('Pantry'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Cellar');

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      expect(renamed, isEmpty);
      expect(find.byType(TextField), findsNothing);
      expect(find.text('Pantry'), findsOneWidget);
    });

    testWidgets('an empty or unchanged name saves nothing', (tester) async {
      await pumpHeader(tester);
      await tester.tap(find.text('Pantry'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '   ');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(renamed, isEmpty);
      expect(find.text('Pantry'), findsOneWidget);
    });

    testWidgets('losing focus saves the name', (tester) async {
      await pumpHeader(tester);
      await tester.tap(find.text('Pantry'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Cellar');

      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();

      expect(renamed, ['Cellar']);
    });

    testWidgets('startEditing focuses the title with its text selected', (
      tester,
    ) async {
      await pumpHeader(tester, startEditing: true);

      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.focusNode!.hasFocus, isTrue);
      expect(
        field.controller!.selection,
        const TextSelection(baseOffset: 0, extentOffset: 6),
      );
    });

    testWidgets('the count badge and add button sit beside the title', (
      tester,
    ) async {
      await pumpHeader(tester);

      final title = tester.getRect(find.text('Pantry'));
      final badge = tester.getRect(find.text('3 items'));
      final add = tester.getRect(find.byIcon(Icons.add));
      expect(badge.left, greaterThan(title.right));
      expect((badge.center.dy - title.center.dy).abs(), lessThan(8));
      expect(add.left, greaterThan(badge.right));
      expect(find.byIcon(Icons.edit), findsNothing);
    });
  });

  testWidgets('CollectionCard shows the count badge beside the title', (
    tester,
  ) async {
    await pump(
      tester,
      const CollectionCard(collection: _collection, productCount: 12),
    );

    final title = tester.getRect(find.text('Pantry'));
    final badge = tester.getRect(find.text('12 items'));
    expect(badge.left, greaterThan(title.right));
    expect((badge.center.dy - title.center.dy).abs(), lessThan(8));
  });

  testWidgets('a kickstart card can fill the width of its section', (
    tester,
  ) async {
    await pump(
      tester,
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CollectionKickstartCard(
            type: CollectionType.inventory,
            onChanged: () async {},
            fillWidth: true,
          ),
        ],
      ),
    );

    expect(tester.getSize(find.byType(Card)).width, 400);
  });
}
