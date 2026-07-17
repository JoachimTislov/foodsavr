// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'transaction_details_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

TransactionDetails _$TransactionDetailsFromJson(Map<String, dynamic> json) =>
    TransactionDetails(
      bonusPointsTotal: (json['bonusPointsTotal'] as num?)?.toInt(),
      bonusPointsTotalDecimal: (json['bonusPointsTotalDecimal'] as num?)
          ?.toDouble(),
      bonusPointsBasedOnReceipt: (json['bonusPointsBasedOnReceipt'] as num?)
          ?.toInt(),
      transactionPayments: json['transactionPayments'] == null
          ? null
          : TransactionPayment.fromJson(
              json['transactionPayments'] as Map<String, dynamic>,
            ),
      rows: (json['rows'] as List<dynamic>?)
          ?.map((e) => TransactionRow.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$TransactionDetailsToJson(TransactionDetails instance) =>
    <String, dynamic>{
      'bonusPointsTotal': instance.bonusPointsTotal,
      'bonusPointsTotalDecimal': instance.bonusPointsTotalDecimal,
      'bonusPointsBasedOnReceipt': instance.bonusPointsBasedOnReceipt,
      'transactionPayments': instance.transactionPayments,
      'rows': instance.rows,
    };
