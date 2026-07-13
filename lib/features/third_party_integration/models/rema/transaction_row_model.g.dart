// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'transaction_row_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

TransactionRow _$TransactionRowFromJson(Map<String, dynamic> json) =>
    TransactionRow(
      productCode: json['productCode'] as String?,
      productDescription: json['productDescription'] as String?,
      prodtxt1: json['prodtxt1'] as String?,
      prodtxt2: json['prodtxt2'] as String?,
      prodtxt3: json['prodtxt3'] as String?,
      productGroupCode: json['productGroupCode'] as String?,
      productGroupDescription: json['productGroupDescription'] as String?,
      bonusBased: json['bonusBased'] as bool?,
      pieces: (json['pieces'] as num?)?.toInt(),
      amount: (json['amount'] as num?)?.toDouble(),
      amountWithoutDeposit: (json['amountWithoutDeposit'] as num?)?.toDouble(),
      discount: (json['discount'] as num?)?.toDouble(),
      volume: (json['volume'] as num?)?.toDouble(),
      unit: json['unit'] as String?,
      deposit: (json['deposit'] as num?)?.toDouble(),
      unitPrice: (json['unitPrice'] as num?)?.toDouble(),
      bonusPoints: (json['bonusPoints'] as num?)?.toInt(),
      bonusPointsDecimal: (json['bonusPointsDecimal'] as num?)?.toDouble(),
    );

Map<String, dynamic> _$TransactionRowToJson(TransactionRow instance) =>
    <String, dynamic>{
      'productCode': instance.productCode,
      'productDescription': instance.productDescription,
      'prodtxt1': instance.prodtxt1,
      'prodtxt2': instance.prodtxt2,
      'prodtxt3': instance.prodtxt3,
      'productGroupCode': instance.productGroupCode,
      'productGroupDescription': instance.productGroupDescription,
      'bonusBased': instance.bonusBased,
      'pieces': instance.pieces,
      'amount': instance.amount,
      'amountWithoutDeposit': instance.amountWithoutDeposit,
      'discount': instance.discount,
      'volume': instance.volume,
      'unit': instance.unit,
      'deposit': instance.deposit,
      'unitPrice': instance.unitPrice,
      'bonusPoints': instance.bonusPoints,
      'bonusPointsDecimal': instance.bonusPointsDecimal,
    };
