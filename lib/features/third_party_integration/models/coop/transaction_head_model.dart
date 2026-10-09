import 'package:foodsavr/features/third_party_integration/models/coop/transaction_model.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'transaction_head_model.freezed.dart';
part 'transaction_head_model.g.dart';

@freezed
abstract class CoopTransactionHead with _$CoopTransactionHead {
  const factory CoopTransactionHead({
    int? id,
    int? purchaseDate,
    double? amount,
    double? bonus,
    String? storeId,
    String? storeName,
    String? receiptNumber,
    bool? scanAndPay,
    List<CoopTransaction>? transactions,
  }) = _CoopTransactionHead;

  factory CoopTransactionHead.fromJson(Map<String, dynamic> json) =>
      _$CoopTransactionHeadFromJson(json);
}
