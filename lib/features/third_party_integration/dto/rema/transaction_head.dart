import 'package:foodsavr/features/third_party_integration/dto/rema/transaction.dart';
import 'package:json_annotation/json_annotation.dart';

part 'transaction_head.g.dart';

@JsonSerializable()
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

  factory TransactionHead.fromJson(Map<String, dynamic> json) =>
      _$TransactionHeadFromJson(json);

  Map<String, dynamic> toJson() => _$TransactionHeadToJson(this);
}
