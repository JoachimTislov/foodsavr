import 'package:freezed_annotation/freezed_annotation.dart';

part 'transaction_row_model.freezed.dart';
part 'transaction_row_model.g.dart';

@freezed
abstract class CoopTransactionRow with _$CoopTransactionRow {
  const CoopTransactionRow._();
  const factory CoopTransactionRow({
    String? productCode,
    String? productDescription,
    String? name,
    String? prodtxt1,

    /// EAN barcode
    String? prodtxt3,
    double? price,
    double? quantity,
    String? unit,
    double? volume,
    double? discount,
  }) = _CoopTransactionRow;

  String get displayName => prodtxt1 ?? name ?? productDescription ?? 'N/A';

  factory CoopTransactionRow.fromJson(Map<String, dynamic> json) =>
      _$CoopTransactionRowFromJson(json);
}
