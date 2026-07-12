import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:foodsavr/features/third_party_integration/dto/rema/transaction_row.dart';
import 'package:foodsavr/features/third_party_integration/models/m_provider.dart';
import 'package:foodsavr/models/m_product.dart';

import '../dto/rema/transaction_head.dart';
import 'base_client.dart';

final class RemaClient extends Client {
  RemaClient(super.logger, super.storage)
    : super(
        provider: Provider.rema,
        requestHeaders: {
          'Ocp-Apim-Subscription-Key': dotenv.get('REMA_API_SUB_KEY'),
        },
      );

  Future<List<Product>> getProducts() async {
    return <Product>[];
  }

  Future<List<TransactionHead>> getTransactions() async {
    List<dynamic> data = await fetch('REMA_TRANSACTIONS', '/heads');
    final transactions = data
        .map((json) => TransactionHead.fromJson(json))
        .toList();
    super.logger.i(transactions);
    return transactions;
  }

  Future<List<TransactionRow>> getTransactionDetails(List<String> ids) async {
    final rows = <TransactionRow>[];
    for (var id in ids) {
      Map<String, dynamic> data = await fetch('REMA_TRANSACTIONS', '/rows/$id');
      rows.add(TransactionRow.fromJson(data));
    }
    super.logger.i(rows);
    return rows;
  }
}
