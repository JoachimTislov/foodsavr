import 'package:flutter_test/flutter_test.dart';
import 'package:foodsavr/services/barcode_lookup_queue.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  Future<SharedPreferencesWithCache> prefs() =>
      SharedPreferencesWithCache.create(
        cacheOptions: const SharedPreferencesWithCacheOptions(
          allowList: {BarcodeLookupQueue.preferenceKey},
        ),
      );

  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.withData({});
  });

  const entry = QueuedBarcodeLookup(
    productId: 'p1',
    barcode: '0000000123456',
    languageCode: 'en',
  );

  test('queued lookups survive a restart', () async {
    final queue = BarcodeLookupQueue(await prefs());
    await queue.enqueue(entry);
    await queue.enqueue(entry);

    final restarted = BarcodeLookupQueue(await prefs());
    expect(restarted.entries, [entry]);

    await restarted.remove(entry);
    expect(BarcodeLookupQueue(await prefs()).length, 0);
  });

  test('a corrupt stored queue is dropped', () async {
    final store = await prefs();
    await store.setString(BarcodeLookupQueue.preferenceKey, '{not json');

    expect(BarcodeLookupQueue(store).length, 0);
  });
}
