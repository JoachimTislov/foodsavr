import 'package:foodsavr/features/third_party_integration/dto/rema/transaction.dart';

final class TransactionHead {
  final int? bonusTotal;
  final double? bonusTotalDecimal;
  final double? purchaseTotal;
  final double? discountTotal;
  final List<Transaction>? transactions;

  TransactionHead({
    this.bonusTotal,
    this.bonusTotalDecimal,
    this.purchaseTotal,
    this.discountTotal,
    this.transactions,
  });
}
