import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:foodsavr/features/third_party_integration/models/m_provider.dart';

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

  Future<List<TransactionHead>> getTransactions() async {
    final data = await fetch('REMA_RECEIPTS');
    // TODO: map from json...
    return <TransactionHead>[];
  }
}
