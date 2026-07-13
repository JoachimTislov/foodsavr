// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'transaction_head_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

TransactionHead _$TransactionHeadFromJson(Map<String, dynamic> json) =>
    TransactionHead(
      bonusTotal: (json['bonusTotal'] as num?)?.toInt(),
      bonusTotalDecimal: (json['bonusTotalDecimal'] as num?)?.toDouble(),
      purchaseTotal: (json['purchaseTotal'] as num?)?.toDouble(),
      discountTotal: (json['discountTotal'] as num?)?.toDouble(),
      transactions: (json['transactions'] as List<dynamic>?)
          ?.map((e) => Transaction.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$TransactionHeadToJson(TransactionHead instance) =>
    <String, dynamic>{
      'bonusTotal': instance.bonusTotal,
      'bonusTotalDecimal': instance.bonusTotalDecimal,
      'purchaseTotal': instance.purchaseTotal,
      'discountTotal': instance.discountTotal,
      'transactions': instance.transactions,
    };
