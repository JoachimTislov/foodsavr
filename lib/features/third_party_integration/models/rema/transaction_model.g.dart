// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'transaction_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Transaction _$TransactionFromJson(Map<String, dynamic> json) => Transaction(
  id: (json['id'] as num?)?.toInt(),
  purchaseDate: (json['purchaseDate'] as num?)?.toInt(),
  storeId: json['storeId'] as String?,
  amount: (json['amount'] as num?)?.toDouble(),
  bonusPoints: (json['bonusPoints'] as num?)?.toInt(),
  bonusPointsDecimal: (json['bonusPointsDecimal'] as num?)?.toDouble(),
  storeName: json['storeName'] as String?,
  verified: json['verified'] as bool?,
  receiptNbr: json['receiptNbr'] as String?,
  scanAndPay: json['scanAndPay'] as bool?,
  transactionPayments: json['transactionPayments'] == null
      ? null
      : TransactionPayment.fromJson(
          json['transactionPayments'] as Map<String, dynamic>,
        ),
);

Map<String, dynamic> _$TransactionToJson(Transaction instance) =>
    <String, dynamic>{
      'id': instance.id,
      'purchaseDate': instance.purchaseDate,
      'storeId': instance.storeId,
      'amount': instance.amount,
      'bonusPoints': instance.bonusPoints,
      'bonusPointsDecimal': instance.bonusPointsDecimal,
      'storeName': instance.storeName,
      'verified': instance.verified,
      'receiptNbr': instance.receiptNbr,
      'scanAndPay': instance.scanAndPay,
      'transactionPayments': instance.transactionPayments,
    };
