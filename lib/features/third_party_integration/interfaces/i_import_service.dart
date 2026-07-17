abstract class IImportService {
  Future<void> getReceiptById(String id);
  Future<void> getReceipts();
  Future<void> getProducts();
}
