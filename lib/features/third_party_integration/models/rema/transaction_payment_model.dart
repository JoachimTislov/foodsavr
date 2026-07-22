import 'package:freezed_annotation/freezed_annotation.dart';

part 'transaction_payment_model.freezed.dart';
part 'transaction_payment_model.g.dart';

@freezed
sealed class TransactionPayment with _$TransactionPayment {
  const factory TransactionPayment({
    String? meansOfPaymentDesc,
    String? amount,
  }) = _TransactionPayment;

  factory TransactionPayment.fromJson(Map<String, Object?> json) =>
      _$TransactionPaymentFromJson(json);
}
