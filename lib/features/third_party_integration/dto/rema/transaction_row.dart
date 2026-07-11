import 'package:foodsavr/features/third_party_integration/dto/rema/transacton_payment.dart';

final class TransactionRow {
  final int? bonusPointsTotal;
  final double? bonusPointsTotalDecimal;
  final int? bonusPointsBasedOnReceipt;
  final List<Row>? rows;
  final TransactionPayment? transactionPayments;

  TransactionRow({
    this.bonusPointsTotal,
    this.bonusPointsTotalDecimal,
    this.bonusPointsBasedOnReceipt,
    this.transactionPayments,
    this.rows,
  });
}

final class Row {
  final String? productCode;
  final String? productDescription;
  final String? prodtxt1;
  final String? prodtxt2;
  final String? prodtxt3;
  final String? productGroupCode;
  final String? productGroupDescription;
  final bool? bonusBased;
  final int? pieces;
  final double? amount;
  final double? amountWithoutDeposit;
  final double? discount;
  final double? volume;
  final String? unit;
  final double? deposit;
  final double? unitPrice;
  final int? bonusPoints;
  final double? bonusPointsDecimal;

  Row({
    this.productCode,
    this.productDescription,
    this.prodtxt1,
    this.prodtxt2,
    this.prodtxt3,
    this.productGroupCode,
    this.productGroupDescription,
    this.bonusBased,
    this.pieces,
    this.amount,
    this.amountWithoutDeposit,
    this.discount,
    this.volume,
    this.unit,
    this.deposit,
    this.unitPrice,
    this.bonusPoints,
    this.bonusPointsDecimal,
  });
}
