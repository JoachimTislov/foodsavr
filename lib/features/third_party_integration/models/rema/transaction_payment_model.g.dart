// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'transaction_payment_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

TransactionPayment _$TransactionPaymentFromJson(Map<String, dynamic> json) =>
    TransactionPayment(
      meansOfPaymentDesc: json['meansOfPaymentDesc'] as String?,
      amount: (json['amount'] as num?)?.toDouble(),
    );

Map<String, dynamic> _$TransactionPaymentToJson(TransactionPayment instance) =>
    <String, dynamic>{
      'meansOfPaymentDesc': instance.meansOfPaymentDesc,
      'amount': instance.amount,
    };
