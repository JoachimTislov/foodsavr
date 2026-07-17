import 'package:foodsavr/features/third_party_integration/models/rema/transaction_payment_model.dart';
import 'package:json_annotation/json_annotation.dart';

part 'transaction_model.g.dart';

@JsonSerializable()
final class Transaction {
  final int? id;
  final int? purchaseDate;
  final String? storeId;
  final double? amount;
  final int? bonusPoints;
  final double? bonusPointsDecimal;
  final String? storeName;
  final bool? verified;
  final String? receiptNbr;
  final bool? scanAndPay;
  final TransactionPayment? transactionPayments;

  Transaction({
    this.id,
    this.purchaseDate,
    this.storeId,
    this.amount,
    this.bonusPoints,
    this.bonusPointsDecimal,
    this.storeName,
    this.verified,
    this.receiptNbr,
    this.scanAndPay,
    this.transactionPayments,
  });

  factory Transaction.fromJson(Map<String, dynamic> json) =>
      _$TransactionFromJson(json);

  Map<String, dynamic> toJson() => _$TransactionToJson(this);
}
