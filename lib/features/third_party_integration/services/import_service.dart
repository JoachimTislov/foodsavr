import 'package:foodsavr/features/third_party_integration/clients/coop_client.dart';
import 'package:foodsavr/features/third_party_integration/clients/rema_client.dart';
import 'package:foodsavr/features/third_party_integration/interfaces/i_import_service.dart';
import 'package:foodsavr/features/third_party_integration/models/provider_model.dart';
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
  final RemaClient _remaClient;
  final CoopClient _coopClient;

  ImportService(
    this._authService,
    this._logger,
    SecureStorage storage,
    http.Client client,
  ) : _remaClient = RemaClient(_logger, storage, client),
      _coopClient = CoopClient(_logger, storage, client);

  @override
  Future<void> getReceiptById(String id) {
    // TODO: implement
    throw UnimplementedError();
  }

  @override
  Future<void> getReceipts() {
    // TODO: implement
    throw UnimplementedError();
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
          _logger.i('Rema products: $products');
        case Provider.coop:
          products.addAll(await _coopClient.getProducts());
          _logger.i('Coop products: $products');
        case Provider.trumf:
        // later
      }
    }
    return products;
  }
}
