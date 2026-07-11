import 'package:foodsavr/features/third_party_integration/models/m_provider.dart';

import 'base_client.dart';

final class CoopClient extends Client {
  CoopClient(super.logger, super.storage) : super(provider: Provider.coop);

  Future<List<dynamic>> getTransactions() async {
    final data = await fetch('COOP_PURCHASE_HISTORY', '/list');
    return [];
  }

  Future<List<dynamic>> getTransactionsForMonth() async {
    final data = await fetch('COOP_PURCHASE_HISTORY', '/month');
    return [];
  }

  Future<List<dynamic>> getTransactionDetails() async {
    final data = await fetch('COOP_PURCHASE_HISTORY', '/details');
    return [];
  }
}
