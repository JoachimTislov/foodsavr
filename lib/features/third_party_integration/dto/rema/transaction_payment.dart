import 'package:json_annotation/json_annotation.dart';

part 'transaction_payment.g.dart';

@JsonSerializable()
final class TransactionPayment {
  final String? meansOfPaymentDesc;
  final double? amount;

  TransactionPayment({this.meansOfPaymentDesc, this.amount});

  factory TransactionPayment.fromJson(Map<String, dynamic> json) =>
      _$TransactionPaymentFromJson(json);

  Map<String, dynamic> toJson() => _$TransactionPaymentToJson(this);
}
