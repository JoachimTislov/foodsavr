import 'package:foodsavr/features/third_party_integration/models/rema/transaction_payment_model.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'transaction_model.freezed.dart';
part 'transaction_model.g.dart';

@freezed
abstract class Transaction with _$Transaction {
  const factory Transaction({
    int? id,
    int? purchaseDate,
    String? storeId,
    double? amount,
    int? bonusPoints,
    double? bonusPointsDecimal,
    String? storeName,
    bool? verified,
    String? receiptNbr,
    bool? scanAndPay,
    TransactionPayment? transactionPayments,
  }) = _Transaction;

  factory Transaction.fromJson(Map<String, dynamic> json) =>
      _$TransactionFromJson(json);
}
