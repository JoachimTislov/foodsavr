import 'package:foodsavr/features/third_party_integration/models/rema/transaction_payment_model.dart';
import 'package:foodsavr/features/third_party_integration/models/rema/transaction_row_model.dart';
import 'package:json_annotation/json_annotation.dart';

part 'transaction_details_model.g.dart';

@JsonSerializable()
final class TransactionDetails {
  final int? bonusPointsTotal;
  final double? bonusPointsTotalDecimal;
  final int? bonusPointsBasedOnReceipt;
  final TransactionPayment? transactionPayments;
  final List<TransactionRow>? rows;

  TransactionDetails({
    this.bonusPointsTotal,
    this.bonusPointsTotalDecimal,
    this.bonusPointsBasedOnReceipt,
    this.transactionPayments,
    this.rows,
  });

  factory TransactionDetails.fromJson(Map<String, dynamic> json) =>
      _$TransactionDetailsFromJson(json);

  Map<String, dynamic> toJson() => _$TransactionDetailsToJson(this);
}
