import 'package:foodsavr/features/third_party_integration/dto/rema/transacton_payment.dart';

final class Transaction {
  final int? purchaseDate;
  final String? storeId;
  final double? amount;
  final int? bonusPoints;
  final double? bonusPointsDecimal;
  final String? storeName;
  final int? id;
  final bool? verified;
  final String? receiptNbr;
  final bool? scanAndPay;
  final TransactionPayment? transactionPayments;

  Transaction({
    this.purchaseDate,
    this.storeId,
    this.amount,
    this.bonusPoints,
    this.bonusPointsDecimal,
    this.storeName,
    this.id,
    this.verified,
    this.receiptNbr,
    this.scanAndPay,
    this.transactionPayments,
  });
}
