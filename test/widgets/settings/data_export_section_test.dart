import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foodsavr/models/collection_model.dart';
import 'package:foodsavr/services/collection_service.dart';
import 'package:foodsavr/services/data_export_service.dart';
import 'package:foodsavr/services/product_service.dart';
import 'package:foodsavr/utils/collection_types.dart';
import 'package:foodsavr/widgets/settings/data_export_section.dart';
import 'package:mocktail/mocktail.dart';

import 'support.dart';

class _Collections extends Mock implements CollectionService {}

class _Products extends Mock implements ProductService {}

const _lists = [
  Collection(id: 'home', name: 'Hjem', userId: 'user-1', productIds: []),
  Collection(
    id: 'weekend',
    name: 'Helg',
    userId: 'user-1',
    productIds: [],
    type: CollectionType.shoppingList,
  ),
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late MockAuthService auth;
  late _Collections collections;
  late _Products products;
  late List<ExportFile> saved;
  late DataExportService service;

  setUp(() async {
    await setUpSettingsWidgetTest();
    auth = MockAuthService();
    when(() => auth.getUserId()).thenReturn('user-1');
    collections = _Collections();
    when(
      () => collections.getCollectionsForUser('user-1'),
    ).thenAnswer((_) async => _lists);
    products = _Products();
    when(
      () => products.getProducts('user-1', forceRefresh: true),
    ).thenAnswer((_) async => []);
    when(
      () => products.getPersonalProducts('user-1'),
    ).thenAnswer((_) async => []);
    saved = [];
    service = DataExportService(
      collections,
      products,
      sink: (file) async {
        saved.add(file);
        return true;
      },
      clock: () => DateTime(2026, 11, 28),
    );
  });

  Future<void> pumpSection(WidgetTester tester, double width) =>
      pumpSettingsWidget(
        tester,
        DataExportSection(service: service, authService: auth),
        width: width,
      );

  List<String> exportedNames(ExportFile file) => [
    for (final line in const LineSplitter().convert(file.content).skip(1))
      line.split(',')[1],
  ];

  group('compact', () {
    testWidgets('exports everything as CSV in one tap', (tester) async {
      await pumpSection(tester, 390);

      expect(find.byType(CheckboxListTile), findsNothing);
      await tester.tap(find.text('Export all (CSV)'));
      await tester.pumpAndSettle();

      expect(saved.single.fileName, 'foodsavr-export-2026-11-28.csv');
      expect(exportedNames(saved.single), ['Hjem', 'Helg']);
      expect(
        find.text('Downloaded foodsavr-export-2026-11-28.csv'),
        findsOneWidget,
      );
    });

    testWidgets('exports a single list by tapping it', (tester) async {
      await pumpSection(tester, 390);

      await tester.tap(find.text('Helg'));
      await tester.pumpAndSettle();

      expect(exportedNames(saved.single), ['Helg']);
    });

    testWidgets('switches the format to JSON', (tester) async {
      await pumpSection(tester, 390);

      await tester.tap(find.text('JSON'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Export all (JSON)'));
      await tester.pumpAndSettle();

      expect(saved.single.format, ExportFormat.json);
      expect(jsonDecode(saved.single.content), isA<Map>());
    });
  });

  group('wide', () {
    testWidgets('selects everything by default', (tester) async {
      await pumpSection(tester, 1200);

      expect(find.text('3 of 3 selected'), findsOneWidget);
      expect(find.text('CSV'), findsOneWidget);
      await tester.tap(find.text('Download'));
      await tester.pumpAndSettle();

      expect(exportedNames(saved.single), ['Hjem', 'Helg']);
    });

    testWidgets('exports only what stays selected', (tester) async {
      await pumpSection(tester, 1200);

      await tester.tap(find.text('Hjem'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Products'));
      await tester.pumpAndSettle();
      expect(find.text('1 of 3 selected'), findsOneWidget);
      await tester.tap(find.text('Download'));
      await tester.pumpAndSettle();

      expect(exportedNames(saved.single), ['Helg']);
    });

    testWidgets('Everything clears and restores the selection', (tester) async {
      await pumpSection(tester, 1200);

      await tester.tap(find.text('Everything'));
      await tester.pumpAndSettle();
      expect(find.text('0 of 3 selected'), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(
              find.ancestor(
                of: find.text('Download'),
                matching: find.bySubtype<FilledButton>(),
              ),
            )
            .onPressed,
        isNull,
      );

      await tester.tap(find.text('Everything'));
      await tester.pumpAndSettle();
      expect(find.text('3 of 3 selected'), findsOneWidget);
    });
  });

  testWidgets('reports a platform without downloads', (tester) async {
    service = DataExportService(
      collections,
      products,
      sink: (_) async => false,
    );
    await pumpSection(tester, 390);

    await tester.tap(find.text('Export all (CSV)'));
    await tester.pumpAndSettle();

    expect(
      find.text('File downloads are only available in the web app.'),
      findsOneWidget,
    );
  });

  testWidgets('reports a failed export', (tester) async {
    when(
      () => products.getProducts('user-1', forceRefresh: true),
    ).thenThrow(Exception('offline'));
    await pumpSection(tester, 390);

    await tester.tap(find.text('Export all (CSV)'));
    await tester.pumpAndSettle();

    expect(find.text('The export failed. Try again.'), findsOneWidget);
    expect(saved, isEmpty);
  });

  testWidgets('offers a retry when the lists cannot be loaded', (tester) async {
    var attempts = 0;
    when(() => collections.getCollectionsForUser('user-1')).thenAnswer((
      _,
    ) async {
      if (attempts++ == 0) throw Exception('offline');
      return _lists;
    });
    await pumpSection(tester, 390);

    expect(find.text('Could not load your lists.'), findsOneWidget);
    await tester.tap(find.text('Try Again'));
    await tester.pumpAndSettle();

    expect(find.text('Could not load your lists.'), findsNothing);
    expect(find.text('Hjem'), findsOneWidget);
  });

  testWidgets('reloads the lists when its tab becomes visible again', (
    tester,
  ) async {
    final visible = ValueNotifier(true);
    addTearDown(visible.dispose);
    await pumpSettingsWidget(
      tester,
      ValueListenableBuilder(
        valueListenable: visible,
        builder: (context, enabled, child) =>
            TickerMode(enabled: enabled, child: child!),
        child: DataExportSection(service: service, authService: auth),
      ),
    );

    visible.value = false;
    await tester.pumpAndSettle();
    visible.value = true;
    await tester.pumpAndSettle();

    verify(() => collections.getCollectionsForUser('user-1')).called(2);
  });
}
