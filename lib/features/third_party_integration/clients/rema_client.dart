import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:foodsavr/features/third_party_integration/models/provider_model.dart';
import 'package:foodsavr/features/third_party_integration/models/rema/transaction_details_model.dart';
import 'package:foodsavr/features/third_party_integration/models/rema/transaction_head_model.dart';
import 'package:foodsavr/features/third_party_integration/models/rema/transaction_row_model.dart';
import 'package:foodsavr/models/product_model.dart';

import 'base_client.dart';

final class RemaClient extends Client {
  RemaClient(super.logger, super.storage, super.client)
    : super(
        provider: Provider.rema,
        requestHeaders: {
          'Ocp-Apim-Subscription-Key': dotenv.get('REMA_API_SUB_KEY'),
        },
      );

  Future<List<Product>> getProducts(String userId) async {
    final products = <Product>[];
    for (var head in await _getTransactions()) {
      final transactions = head.transactions;
      if (transactions != null) {
        for (var transaction in transactions) {
          final id = transaction.id;
          if (id == null) continue;
          final details = await _getTransactionDetails(id);
          for (TransactionRow row in details.rows ?? []) {
            final id = row.productCode;
            final barcode = row.prodtxt3;
            final description = row.productDescription;
            if (id != null && barcode != null && description != null) {
              products.add(
                Product(
                  id: id,
                  name: row.name,
                  description: description,
                  userId: userId,
                  barcode: barcode,
                ),
              );
            }
          }
        }
      }
    }
    return products;
  }

  Future<TransactionDetails> _getTransactionDetails(int id) async {
    Map<String, dynamic> data = await fetch('REMA_TRANSACTIONS', '/rows/$id');
    final details = TransactionDetails.fromJson(data);
    super.logger.i(details);
    return details;
  }

  Future<List<TransactionHead>> _getTransactions() async {
    List<dynamic> data = await fetch('REMA_TRANSACTIONS', '/heads');
    final transactions = data
        .map((json) => TransactionHead.fromJson(json))
        .toList();
    super.logger.i(transactions);
    return transactions;
  }
}
