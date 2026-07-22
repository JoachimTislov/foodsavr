import 'package:foodsavr/features/third_party_integration/models/rema/transaction_model.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'transaction_head_model.freezed.dart';
part 'transaction_head_model.g.dart';

@freezed
abstract class TransactionHead with _$TransactionHead {
  const factory TransactionHead({
    int? bonusTotal,
    double? bonusTotalDecimal,
    double? purchaseTotal,
    double? discountTotal,
    List<Transaction>? transactions,
  }) = _TransactionHead;

  factory TransactionHead.fromJson(Map<String, dynamic> json) =>
      _$TransactionHeadFromJson(json);
}
