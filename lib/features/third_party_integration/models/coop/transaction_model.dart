import 'package:freezed_annotation/freezed_annotation.dart';

part 'transaction_model.freezed.dart';
part 'transaction_model.g.dart';

@freezed
abstract class CoopTransaction with _$CoopTransaction {
  const factory CoopTransaction({
    int? id,
    int? purchaseDate,
    double? amount,
    int? bonusPoints,
    String? storeName,
    bool? verified,
  }) = _CoopTransaction;

  factory CoopTransaction.fromJson(Map<String, dynamic> json) =>
      _$CoopTransactionFromJson(json);
}
