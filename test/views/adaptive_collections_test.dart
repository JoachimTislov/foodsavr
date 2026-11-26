import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foodsavr/controllers/preferences_controller.dart';
import 'package:foodsavr/interfaces/i_auth_service.dart';
import 'package:foodsavr/models/collection_model.dart';
import 'package:foodsavr/models/product_model.dart';
import 'package:foodsavr/service_locator.dart';
import 'package:foodsavr/services/collection_service.dart';
import 'package:foodsavr/services/product_service.dart';
import 'package:foodsavr/utils/collection_types.dart';
import 'package:foodsavr/views/collection_detail_view.dart';
import 'package:foodsavr/views/collection_list_view.dart';
import 'package:foodsavr/views/dynamic_collection_view.dart';
import 'package:foodsavr/widgets/collection/delete_collection_sheet.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Auth extends Mock implements IAuthService {}

class _Products extends Mock implements ProductService {}

class _Collections extends Mock implements CollectionService {}

class _Preferences extends ChangeNotifier implements PreferencesController {
  @override
  int get expiringSoonDays => 5;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const _pantry = Collection(
  id: 'c1',
  name: 'Pantry',
  productIds: [],
  userId: 'user',
);
const _fridge = Collection(
  id: 'c2',
  name: 'Fridge',
  productIds: [],
  userId: 'user',
);

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    EasyLocalization.logger.enableLevels = [];
    await EasyLocalization.ensureInitialized();
  });

  setUp(() async {
    await getIt.reset();
    final auth = _Auth();
    when(() => auth.getUserId()).thenReturn('user');
    final collections = _Collections();
    when(
      () => collections.getCollectionsForUser('user'),
    ).thenAnswer((_) async => [_pantry, _fridge]);
    when(() => collections.getCollection(any())).thenAnswer(
      (i) async => i.positionalArguments.first == 'c1' ? _pantry : _fridge,
    );
    when(
      () => collections.resolveCounts('user', any()),
    ).thenAnswer((_) async => {'c1': 0, 'c2': 0});
    when(
      () => collections.loadContents(_pantry),
    ).thenAnswer((_) async => (_pantry, <Product>[]));
    when(
      () => collections.loadContents(_fridge),
    ).thenAnswer((_) async => (_fridge, <Product>[]));
    when(
      () => collections.resolveContents(_pantry),
    ).thenAnswer((_) async => (_pantry, <Product>[], authoritative: true));
    getIt
      ..registerSingleton<IAuthService>(auth)
      ..registerSingleton<CollectionService>(collections)
      ..registerSingleton<ProductService>(_Products())
      ..registerSingleton<PreferencesController>(_Preferences());
  });

  tearDown(() => getIt.reset());

  Future<void> pump(WidgetTester tester, double width) async {
    // The test font (Ahem) is far wider than the real one.
    tester.platformDispatcher.textScaleFactorTestValue = 0.3;
    addTearDown(tester.platformDispatcher.clearAllTestValues);
    tester.view.physicalSize = Size(width, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      EasyLocalization(
        supportedLocales: const [Locale('en')],
        path: 'assets/translations',
        child: const MaterialApp(
          home: CollectionListView(typeFilter: CollectionType.inventory),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  for (final width in [400.0, 700.0]) {
    testWidgets('tapping a collection opens a page at $width px', (
      tester,
    ) async {
      await pump(tester, width);
      expect(find.text('Pantry'), findsOneWidget);

      await tester.tap(find.text('Pantry'));
      await tester.pumpAndSettle();

      expect(find.byType(CollectionDetailView), findsOneWidget);
      expect(find.text('Fridge'), findsNothing);
    });
  }

  testWidgets('a failed refresh after returning from detail can be retried', (
    tester,
  ) async {
    await pump(tester, 400);
    await tester.tap(find.text('Pantry'));
    await tester.pumpAndSettle();

    final collections = getIt<CollectionService>();
    when(
      () => collections.getCollectionsForUser('user'),
    ).thenAnswer((_) async => throw StateError('offline'));
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byType(SnackBarAction), findsOneWidget);

    when(
      () => collections.getCollectionsForUser('user'),
    ).thenAnswer((_) async => [_fridge]);
    await tester.tap(find.byType(SnackBarAction));
    await tester.pumpAndSettle();
    expect(find.text('Pantry'), findsNothing);
    expect(find.text('Fridge'), findsOneWidget);
  });

  testWidgets('expanded width shows list and detail side by side', (
    tester,
  ) async {
    await pump(tester, 1300);
    expect(find.byType(CollectionDetailView), findsNothing);
    expect(find.byIcon(Icons.touch_app_outlined), findsOneWidget);

    await tester.tap(find.text('Fridge'));
    await tester.pumpAndSettle();

    expect(find.byType(CollectionDetailView), findsOneWidget);
    expect(find.text('Pantry'), findsOneWidget);
    // The list stays visible next to the detail header.
    expect(find.text('Fridge'), findsNWidgets(2));
    expect(find.byIcon(Icons.arrow_back), findsNothing);

    await tester.tap(find.text('Pantry'));
    await tester.pumpAndSettle();
    expect(find.text('Pantry'), findsNWidgets(2));
    expect(find.text('Fridge'), findsOneWidget);
  });

  testWidgets('deleting the only inventory keeps the tab open', (tester) async {
    final collections = getIt<CollectionService>();
    var deleted = false;
    when(
      () => collections.getCollectionsForUser('user'),
    ).thenAnswer((_) async => deleted ? [] : [_pantry]);
    when(() => collections.deleteCollectionOnly(_pantry.id)).thenAnswer((
      _,
    ) async {
      deleted = true;
    });

    await tester.pumpWidget(
      EasyLocalization(
        supportedLocales: const [Locale('en')],
        path: 'assets/translations',
        child: const MaterialApp(
          home: DynamicCollectionView(type: CollectionType.inventory),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(DeleteCollectionSheet),
        matching: find.byType(FilledButton),
      ),
    );
    await tester.pumpAndSettle();

    expect(deleted, isTrue);
    expect(find.byType(DynamicCollectionView), findsOneWidget);
    expect(find.byType(CollectionDetailView), findsNothing);
    expect(find.byType(CollectionListView), findsOneWidget);
  });

  testWidgets('a collection of only dangling IDs offers the empty choices', (
    tester,
  ) async {
    const ghosts = Collection(
      id: 'c3',
      name: 'Ghosts',
      productIds: ['deleted-product'],
      userId: 'user',
    );
    final collections = getIt<CollectionService>();
    var deleted = false;
    when(
      () => collections.getCollectionsForUser('user'),
    ).thenAnswer((_) async => deleted ? [] : [ghosts]);
    when(() => collections.getCollection('c3')).thenAnswer((_) async => ghosts);
    when(() => collections.loadContents(ghosts)).thenAnswer(
      (_) async => (ghosts.copyWith(productIds: const []), <Product>[]),
    );
    when(() => collections.resolveContents(ghosts)).thenAnswer(
      (_) async => (
        ghosts.copyWith(productIds: const []),
        <Product>[],
        authoritative: true,
      ),
    );
    when(() => collections.deleteCollectionOnly('c3')).thenAnswer((_) async {
      deleted = true;
    });

    await tester.pumpWidget(
      EasyLocalization(
        supportedLocales: const [Locale('en')],
        path: 'assets/translations',
        child: const MaterialApp(
          home: DynamicCollectionView(type: CollectionType.inventory),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();

    final sheet = find.byType(DeleteCollectionSheet);
    expect(
      find.descendant(of: sheet, matching: find.byType(OutlinedButton)),
      findsNothing,
    );
    expect(
      find.descendant(of: sheet, matching: find.byType(FilledButton)),
      findsOneWidget,
    );
    await tester.tap(
      find.descendant(of: sheet, matching: find.byType(FilledButton)),
    );
    await tester.pumpAndSettle();

    expect(deleted, isTrue);
    verifyZeroInteractions(getIt<ProductService>());
  });

  testWidgets('a product added elsewhere after loading offers item choices', (
    tester,
  ) async {
    final stocked = _pantry.copyWith(productIds: ['milk']);
    const milk = Product(
      id: 'milk',
      name: 'Milk',
      description: '',
      userId: 'user',
    );
    final collections = getIt<CollectionService>();
    var added = false;
    when(
      () => collections.getCollectionsForUser('user'),
    ).thenAnswer((_) async => [_pantry]);
    when(
      () => collections.getCollection('c1'),
    ).thenAnswer((_) async => added ? stocked : _pantry);
    when(
      () => collections.resolveContents(stocked),
    ).thenAnswer((_) async => (stocked, [milk], authoritative: true));
    when(
      () => collections.getCollectionsForUser(
        'user',
        type: CollectionType.inventory,
      ),
    ).thenAnswer((_) async => [stocked]);

    await tester.pumpWidget(
      EasyLocalization(
        supportedLocales: const [Locale('en')],
        path: 'assets/translations',
        child: const MaterialApp(
          home: DynamicCollectionView(type: CollectionType.inventory),
        ),
      ),
    );
    await tester.pumpAndSettle();
    added = true;
    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byType(DeleteCollectionSheet),
        matching: find.byType(OutlinedButton),
      ),
      findsOneWidget,
    );
  });
}
