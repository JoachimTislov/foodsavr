import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foodsavr/interfaces/i_auth_service.dart';
import 'package:foodsavr/interfaces/i_receipt_repository.dart';
import 'package:foodsavr/models/receipt_record.dart';
import 'package:foodsavr/service_locator.dart';
import 'package:foodsavr/views/receipt_list_view.dart';
import 'package:foodsavr/widgets/receipt/receipt_list_tile.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/test_translation_loader.dart';

class _Auth extends Mock implements IAuthService {}

class _Receipts implements IReceiptRepository {
  _Receipts(this.records);

  final List<ReceiptRecord> records;

  @override
  Future<bool> exists(String userId, String receiptId) async => false;

  @override
  Future<bool> create(String userId, ReceiptRecord record) async => false;

  @override
  Future<List<ReceiptRecord>> list(String userId) async => records;
}

ReceiptRecord _record(String store, DateTime at, int items) => ReceiptRecord(
  id: 'receipt:$store:1',
  provider: store,
  externalId: '1',
  occurredAt: at,
  store: store,
  itemCount: items,
  productIds: const [],
);

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    EasyLocalization.logger.enableLevels = [];
    await initializeDateFormatting('en', null);
    await EasyLocalization.ensureInitialized();
  });

  setUp(() async {
    await getIt.reset();
    final auth = _Auth();
    when(() => auth.getUserId()).thenReturn('user');
    getIt.registerSingleton<IAuthService>(auth);
  });

  tearDown(() => getIt.reset());

  Future<void> pump(WidgetTester tester, List<ReceiptRecord> records) async {
    getIt.registerSingleton<IReceiptRepository>(_Receipts(records));
    await tester.pumpWidget(
      EasyLocalization(
        supportedLocales: const [Locale('en')],
        path: 'assets/translations',
        fallbackLocale: const Locale('en'),
        assetLoader: TestTranslationLoader(),
        child: Builder(
          builder: (context) => MaterialApp(
            locale: context.locale,
            supportedLocales: context.supportedLocales,
            localizationsDelegates: context.localizationDelegates,
            home: const ReceiptListView(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('lists receipts', (tester) async {
    await pump(tester, [
      _record('Rema', DateTime(2026, 3, 2), 4),
      _record('Kiwi', DateTime(2026, 3, 1), 1),
    ]);

    expect(find.byType(ReceiptListTile), findsNWidgets(2));
    expect(find.text('Rema'), findsOneWidget);
    expect(find.text('4 items'), findsOneWidget);
  });

  testWidgets('shows the empty state with a scan action', (tester) async {
    await pump(tester, const []);

    expect(find.text('No receipts yet'), findsOneWidget);
    expect(find.text('Scan Receipt'), findsOneWidget);
  });

  test('parses a stored raw event', () {
    final record = ReceiptRecord.fromFirestore({
      'id': 'receipt:rema:abc',
      'source': 'receipt',
      'provider': 'rema',
      'externalId': 'abc',
      'occurredAt': Timestamp.fromDate(DateTime.utc(2026, 3, 2)),
      'payload': {
        'store': 'Rema',
        'purchaseDate': '2026-03-02T00:00:00.000Z',
        'itemCount': 2,
        'collectionId': 'c1',
        'productIds': ['p1', 'p2'],
      },
    });

    expect(record.store, 'Rema');
    expect(record.itemCount, 2);
    expect(record.productIds, ['p1', 'p2']);
    expect(record.collectionId, 'c1');
    expect(record.purchaseDate, DateTime.utc(2026, 3, 2));
  });
}
