import 'package:foodsavr/features/third_party_integration/models/coop/transaction_row_model.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'transaction_details_model.freezed.dart';
part 'transaction_details_model.g.dart';

@freezed
abstract class CoopTransactionDetails with _$CoopTransactionDetails {
  const factory CoopTransactionDetails({
    int? receiptNumber,
    double? amount,
    double? discount,
    List<CoopTransactionRow>? rows,
  }) = _CoopTransactionDetails;

  factory CoopTransactionDetails.fromJson(Map<String, dynamic> json) =>
      _$CoopTransactionDetailsFromJson(json);
}
