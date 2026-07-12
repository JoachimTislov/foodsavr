import 'package:json_annotation/json_annotation.dart';

part 'transaction_row.g.dart';

@JsonSerializable()
final class TransactionRow {
  final String? productCode;
  final String? productDescription;
  final String? prodtxt1;
  final String? prodtxt2;
  final String? prodtxt3;
  final String? productGroupCode;
  final String? productGroupDescription;
  final bool? bonusBased;
  final int? pieces;
  final double? amount;
  final double? amountWithoutDeposit;
  final double? discount;
  final double? volume;
  final String? unit;
  final double? deposit;
  final double? unitPrice;
  final int? bonusPoints;
  final double? bonusPointsDecimal;

  TransactionRow({
    this.productCode,
    this.productDescription,
    this.prodtxt1,
    this.prodtxt2,
    this.prodtxt3,
    this.productGroupCode,
    this.productGroupDescription,
    this.bonusBased,
    this.pieces,
    this.amount,
    this.amountWithoutDeposit,
    this.discount,
    this.volume,
    this.unit,
    this.deposit,
    this.unitPrice,
    this.bonusPoints,
    this.bonusPointsDecimal,
  });

  factory TransactionRow.fromJson(Map<String, dynamic> json) =>
      _$TransactionRowFromJson(json);

  Map<String, dynamic> toJson() => _$TransactionRowToJson(this);
}
