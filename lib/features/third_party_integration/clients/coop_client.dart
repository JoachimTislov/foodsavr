import 'package:foodsavr/features/third_party_integration/models/coop/transaction_details_model.dart';
import 'package:foodsavr/features/third_party_integration/models/coop/transaction_head_model.dart';
import 'package:foodsavr/features/third_party_integration/models/provider_model.dart';
import 'package:foodsavr/models/product_model.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'base_client.dart';

final class CoopClient extends Client {
  CoopClient(super.logger, super.storage, super.client)
    : super(
        provider: Provider.coop,
        requestHeaders: {
          'Ocp-Apim-Subscription-Key': dotenv.get('COOP_API_SUB_KEY'),
        },
      );

  Future<List<CoopTransactionHead>> getTransactions() async {
    final data = await fetch('COOP_PURCHASE_HISTORY', '/dashboard');
    if (data is! List) return [];
    final heads = data
        .map((json) => CoopTransactionHead.fromJson(json))
        .toList();
    logger.i('Coop transactions: ${heads.length}');
    return heads;
  }

  Future<CoopTransactionDetails> getTransactionDetails(int id) async {
    final data = await fetch('COOP_PURCHASE_HISTORY', '/details/$id');
    final details = CoopTransactionDetails.fromJson(data);
    logger.i(details);
    return details;
  }

  Future<List<Product>> getProducts(String userId) async {
    final products = <Product>[];
    for (final head in await getTransactions()) {
      final id = head.id;
      if (id == null) continue;
      final details = await getTransactionDetails(id);
      for (final row in details.rows ?? []) {
        final productCode = row.productCode;
        final barcode = row.prodtxt3;
        final description = row.productDescription;
        if (productCode != null && barcode != null && description != null) {
          products.add(
            Product(
              id: productCode,
              name: row.displayName,
              description: description,
              userId: userId,
              barcode: barcode,
            ),
          );
        }
      }
    }
    return products;
  }
}
