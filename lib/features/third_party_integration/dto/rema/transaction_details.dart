import 'package:foodsavr/features/third_party_integration/dto/rema/transaction_row.dart';
import 'package:foodsavr/features/third_party_integration/dto/rema/transacton_payment.dart';
import 'package:json_annotation/json_annotation.dart';

part 'transaction_details.g.dart';

@JsonSerializable()
final class TransactionDetails {
  final int? bonusPointsTotal;
  final double? bonusPointsTotalDecimal;
  final int? bonusPointsBasedOnReceipt;
  final List<TransactionRow>? rows;
  final TransactionPayment? transactionPayments;

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
