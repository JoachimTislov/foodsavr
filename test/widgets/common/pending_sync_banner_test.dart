import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foodsavr/services/barcode_lookup_queue.dart';
import 'package:foodsavr/services/sync_status.dart';
import 'package:foodsavr/widgets/common/pending_sync_banner.dart';
import 'package:logger/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/test_translation_loader.dart';

void main() {
  final loader = TestTranslationLoader();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    EasyLocalization.logger.enableLevels = [];
    await EasyLocalization.ensureInitialized();
  });

  testWidgets('shows pending writes and queued lookups, hides when synced', (
    tester,
  ) async {
    final sync = SyncStatus.withTimeout(
      Logger(level: Level.off),
      Duration.zero,
    );
    final queue = BarcodeLookupQueue.memory();
    await tester.pumpWidget(
      EasyLocalization(
        supportedLocales: const [Locale('en')],
        path: 'assets/translations',
        fallbackLocale: const Locale('en'),
        assetLoader: loader,
        child: Builder(
          builder: (context) => MaterialApp(
            localizationsDelegates: context.localizationDelegates,
            supportedLocales: context.supportedLocales,
            locale: context.locale,
            home: Scaffold(
              body: PendingSyncBanner(syncStatus: sync, lookupQueue: queue),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.cloud_sync_outlined), findsNothing);

    final ack = Completer<void>();
    await tester.runAsync(() async {
      await sync.queue(() => ack.future);
      await queue.enqueue(
        const QueuedBarcodeLookup(
          productId: 'p1',
          barcode: '123',
          languageCode: 'en',
        ),
      );
    });
    await tester.pump();
    expect(find.text('2 changes waiting to sync'), findsOneWidget);

    await tester.runAsync(() async {
      ack.complete();
      await queue.remove(queue.entries.single);
      await pumpEventQueue();
    });
    await tester.pump();
    expect(find.byIcon(Icons.cloud_sync_outlined), findsNothing);
  });
}
