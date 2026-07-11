import 'package:foodsavr/features/third_party_integration/interfaces/i_import_service.dart';
import 'package:injectable/injectable.dart';

@LazySingleton(as: IImportService)
class ImportService implements IImportService {
  @override
  Future<void> getReceiptById() {
    // TODO: implement
    throw UnimplementedError();
  }

  @override
  Future<void> getReceipts() {
    // TODO: implement
    throw UnimplementedError();
  }

  @override
  Future<void> getProducts() {
    // TODO: implement
    throw UnimplementedError();
  }
}
