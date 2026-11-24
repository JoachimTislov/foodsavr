import 'package:foodsavr/features/third_party_integration/clients/coop_client.dart';
import 'package:foodsavr/features/third_party_integration/clients/rema_client.dart';
import 'package:foodsavr/features/third_party_integration/interfaces/i_import_service.dart';
import 'package:foodsavr/features/third_party_integration/models/provider_model.dart';
import 'package:foodsavr/features/third_party_integration/services/store_credentials.dart';
import 'package:foodsavr/interfaces/i_auth_service.dart';
import 'package:foodsavr/models/product_model.dart';
import 'package:foodsavr/services/secure_storage_service.dart';
import 'package:injectable/injectable.dart';
import 'package:logger/logger.dart';
import 'package:http/http.dart' as http;

@LazySingleton(as: IImportService)
class ImportService implements IImportService {
  final IAuthService _authService;
  final Logger _logger;
  final SecureStorage _storage;
  final http.Client _client;

  // Clients read provider keys from the environment on construction, so they
  // are created on first use to keep startup independent of the env file.
  late final RemaClient _remaClient = RemaClient(
    _logger,
    _credentials,
    _client,
  );
  late final CoopClient _coopClient = CoopClient(
    _logger,
    _credentials,
    _client,
  );
  late final StoreCredentials _credentials =
      _injectedCredentials ?? StoreCredentials(_storage, _client, _logger);
  final StoreCredentials? _injectedCredentials;

  ImportService(
    this._authService,
    this._logger,
    this._storage,
    this._client, {
    StoreCredentials? credentials,
  }) : _injectedCredentials = credentials;

  @override
  Future<void> getReceiptById(String id) {
    throw UnimplementedError('getReceiptById is not implemented yet');
  }

  @override
  Future<void> getReceipts() {
    throw UnimplementedError('getReceipts is not implemented yet');
  }

  @override
  Future<List<Product>> getProducts() async {
    final userId = _authService.getUserId();
    if (userId == null) return [];
    final List<Product> products = [];
    for (var provider in Provider.values) {
      switch (provider) {
        case Provider.rema:
          products.addAll(await _remaClient.getProducts(userId));
        case Provider.coop:
          products.addAll(await _coopClient.getProducts());
        case Provider.trumf:
        // later
      }
    }
    return products;
  }
}
