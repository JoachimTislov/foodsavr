import 'package:freezed_annotation/freezed_annotation.dart';

part 'transaction_row_model.freezed.dart';
part 'transaction_row_model.g.dart';

@freezed
abstract class TransactionRow with _$TransactionRow {
  const TransactionRow._();
  const factory TransactionRow({
    String? productCode,
    String? productDescription,

    /// primary name
    String? prodtxt1,

    /// secondary name
    String? prodtxt2,

    /// EAN barcode
    String? prodtxt3,

    String? productGroupCode,
    String? productGroupDescription,
    bool? bonusBased,
    int? pieces,
    double? amount,
    double? amountWithoutDeposit,
    double? discount,
    double? volume,
    String? unit,
    double? deposit,
    double? unitPrice,
    int? bonusPoints,
    double? bonusPointsDecimal,
  }) = _TransactionRow;

  String get name {
    return prodtxt1 ?? prodtxt2 ?? 'N/A';
  }

  factory TransactionRow.fromJson(Map<String, dynamic> json) =>
      _$TransactionRowFromJson(json);
}
