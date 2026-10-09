import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foodsavr/features/third_party_integration/clients/coop_client.dart';
import 'package:foodsavr/features/third_party_integration/models/provider_model.dart';
import 'package:foodsavr/services/secure_storage_service.dart';
import 'package:http/http.dart' as http;
import 'package:logger/logger.dart';

const _envFile = '''
COOP_API_URL=https://api.coop.no/user/pay/history
COOP_API_SUB_KEY=test-sub-key
COOP_PURCHASE_HISTORY=/api
''';

class _NeverUsedStorage extends Fake implements FlutterSecureStorage {}

class _FakeSecureStorage extends SecureStorage {
  _FakeSecureStorage() : super(_NeverUsedStorage());

  final Map<String, String> _store = {};

  @override
  Future<String?> read(Provider provider, Key key) async =>
      _store['${provider.name}.${key.name}'];

  @override
  Future<void> write(Provider provider, Key key, String? v) async {
    if (v == null) {
      _store.remove('${provider.name}.${key.name}');
    } else {
      _store['${provider.name}.${key.name}'] = v;
    }
  }
}

void main() {
  setUpAll(() {
    dotenv.loadFromString(envString: _envFile);
  });

  test('getTransactions returns parsed heads', () async {
    final storage = _FakeSecureStorage()
      ..write(Provider.coop, Key.access_token, 'token');
    final httpClient = _StubHttpClient({
      'https://api.coop.no/user/pay/history/api/dashboard': http.Response(
        jsonEncode([
          {
            'id': 123,
            'purchaseDate': 1760000000000,
            'amount': 199.5,
            'storeName': 'Coop Mega Oslo',
          },
        ]),
        200,
      ),
    });
    final client = CoopClient(Logger(), storage, httpClient);

    final transactions = await client.getTransactions();

    expect(transactions, hasLength(1));
    expect(transactions.first.id, 123);
    expect(transactions.first.storeName, 'Coop Mega Oslo');
  });

  test('getTransactionDetails parses rows', () async {
    final storage = _FakeSecureStorage()
      ..write(Provider.coop, Key.access_token, 'token');
    final httpClient = _StubHttpClient({
      'https://api.coop.no/user/pay/history/api/details/123': http.Response(
        jsonEncode({
          'receiptNumber': 123,
          'amount': 42.0,
          'rows': [
            {
              'productCode': '73900',
              'productDescription': 'Tine melk',
              'prodtxt1': 'Tine melk',
              'prodtxt3': '7040915000123',
              'price': 21.0,
              'quantity': 2,
            },
          ],
        }),
        200,
      ),
    });
    final client = CoopClient(Logger(), storage, httpClient);

    final details = await client.getTransactionDetails(123);

    expect(details.rows, hasLength(1));
    expect(details.rows!.first.prodtxt3, '7040915000123');
    expect(details.rows!.first.displayName, 'Tine melk');
  });

  test('getProducts returns enriched products', () async {
    final storage = _FakeSecureStorage()
      ..write(Provider.coop, Key.access_token, 'token');
    final httpClient = _StubHttpClient({
      'https://api.coop.no/user/pay/history/api/dashboard': http.Response(
        jsonEncode([
          {'id': 123},
        ]),
        200,
      ),
      'https://api.coop.no/user/pay/history/api/details/123': http.Response(
        jsonEncode({
          'rows': [
            {
              'productCode': '73900',
              'productDescription': 'Tine melk',
              'prodtxt1': 'Tine melk',
              'prodtxt3': '7040915000123',
              'price': 21.0,
            },
          ],
        }),
        200,
      ),
    });
    final client = CoopClient(Logger(), storage, httpClient);

    final products = await client.getProducts('user-1');

    expect(products, hasLength(1));
    expect(products.first.id, '73900');
    expect(products.first.barcode, '7040915000123');
    expect(products.first.userId, 'user-1');
  });

  test('returns no transactions when no access token stored', () async {
    final storage = _FakeSecureStorage();
    final httpClient = _StubHttpClient({});
    final client = CoopClient(Logger(), storage, httpClient);

    final transactions = await client.getTransactions();

    expect(transactions, isEmpty);
    expect(httpClient.requestCount, 0);
  });
}

class _StubHttpClient extends http.BaseClient {
  _StubHttpClient(this._routes);

  final Map<String, http.Response> _routes;
  int requestCount = 0;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    requestCount++;
    final response = _routes[request.url.toString()];
    if (response == null) {
      return http.StreamedResponse(Stream.value(utf8.encode('not found')), 404);
    }
    return http.StreamedResponse(
      Stream.value(response.bodyBytes),
      response.statusCode,
    );
  }
}
