import 'package:foodsavr/features/third_party_integration/clients/coop_client.dart';
import 'package:foodsavr/features/third_party_integration/clients/rema_client.dart';
import 'package:foodsavr/features/third_party_integration/interfaces/i_import_service.dart';
import 'package:foodsavr/features/third_party_integration/models/m_provider.dart';
import 'package:foodsavr/services/s_secure_storage.dart';
import 'package:injectable/injectable.dart';
import 'package:logger/logger.dart';

@LazySingleton(as: IImportService)
class ImportService implements IImportService {
  final Logger _logger;
  final RemaClient _remaClient;
  final CoopClient _coopClient;

  ImportService(this._logger, SecureStorage storage)
    : _remaClient = RemaClient(_logger, storage),
      _coopClient = CoopClient(_logger, storage);

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
  Future<void> getProducts() async {
    for (var provider in Provider.values) {
      switch (provider) {
        case Provider.rema:
          final transactions = await _remaClient.getProducts();
          _logger.i(transactions);
        case Provider.coop:
        // later
        case Provider.trumf:
        // later
      }
    }
  }
}
