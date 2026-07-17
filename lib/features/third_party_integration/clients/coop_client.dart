import 'package:foodsavr/features/third_party_integration/models/provider_model.dart';
import 'package:foodsavr/models/product_model.dart';

import 'base_client.dart';

final class CoopClient extends Client {
  CoopClient(super.logger, super.storage, super.client)
    : super(provider: Provider.coop);

  Future<List<Product>> getProducts() async {
    return <Product>[];
  }

  Future<List<dynamic>> getTransactions() async {
    // final data = await fetch('COOP_PURCHASE_HISTORY', '/list');
    return [];
  }

  Future<List<dynamic>> getTransactionsForMonth() async {
    // final data = await fetch('COOP_PURCHASE_HISTORY', '/month');
    return [];
  }

  Future<List<dynamic>> getTransactionDetails() async {
    // final data = await fetch('COOP_PURCHASE_HISTORY', '/details');
    return [];
  }
}
