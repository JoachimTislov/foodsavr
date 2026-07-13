import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:foodsavr/features/third_party_integration/dto/rema/transaction_details.dart';
import 'package:foodsavr/features/third_party_integration/models/m_provider.dart';
import 'package:foodsavr/models/m_product.dart';

import '../dto/rema/transaction_head.dart';
import 'base_client.dart';

final class RemaClient extends Client {
  RemaClient(super.logger, super.storage, super.client)
    : super(
        provider: Provider.rema,
        requestHeaders: {
          'Ocp-Apim-Subscription-Key': dotenv.get('REMA_API_SUB_KEY'),
        },
      );

  Future<List<Product>> getProducts() async {
    final transactionHeads = await getTransactions();
    final details = <Map<int, TransactionDetails>>{};
    for (var head in transactionHeads) {
      final transactions = head.transactions;
      if (transactions != null) {
        for (var transaction in transactions) {
          final id = transaction.id;
          if (id != null) details.add(await getTransactionDetails(id));
        }
      }
    }
    // TODO: map to product...
    return <Product>[];
  }

  Future<Map<int, TransactionDetails>> getTransactionDetails(int id) async {
    Map<String, dynamic> data = await fetch('REMA_TRANSACTIONS', '/rows/$id');
    final row = TransactionDetails.fromJson(data);
    super.logger.i(row);
    return {id: row};
  }

  Future<List<TransactionHead>> getTransactions() async {
    List<dynamic> data = await fetch('REMA_TRANSACTIONS', '/heads');
    final transactions = data
        .map((json) => TransactionHead.fromJson(json))
        .toList();
    super.logger.i(transactions);
    return transactions;
  }
}
