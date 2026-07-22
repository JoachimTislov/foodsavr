import 'package:foodsavr/features/third_party_integration/models/rema/transaction_payment_model.dart';
import 'package:foodsavr/features/third_party_integration/models/rema/transaction_row_model.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'transaction_details_model.freezed.dart';
part 'transaction_details_model.g.dart';

@freezed
abstract class TransactionDetails with _$TransactionDetails {
  const factory TransactionDetails({
    int? bonusPointsTotal,
    double? bonusPointsTotalDecimal,
    int? bonusPointsBasedOnReceipt,
    TransactionPayment? transactionPayments,
    List<TransactionRow>? rows,
  }) = _TransactionDetails;

  factory TransactionDetails.fromJson(Map<String, dynamic> json) =>
      _$TransactionDetailsFromJson(json);
}
