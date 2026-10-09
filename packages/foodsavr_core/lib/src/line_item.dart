import 'package:meta/meta.dart';

/// Where a line item came from.
enum IngestionSource {
  /// OCR'd paper receipt (e.g. via receipt_recognition).
  receipt,

  /// Grocery loyalty API import (e.g. Rema Æ, Coop Member).
  loyaltyApi,

  /// Barcode scan with an exact product lookup (e.g. Open Food Facts).
  barcode,

  /// Free text typed by the user or extracted from a recipe.
  freeText,
}

/// Unit of measure for a line item.
enum LineItemUnit { piece, gram, kilogram, liter, milliliter, package }

/// A single normalized food item flowing through the ingestion pipeline.
///
/// [rawName] is the input as received; [normalizedName] is the cleaned form
/// used for matching. [matchedProductId] and [matchConfidence] are filled in
/// by the matcher; [confidence] by the confidence gate.
@immutable
class LineItem {
  const LineItem({
    required this.id,
    required this.rawName,
    this.normalizedName = '',
    this.quantity = 1,
    this.unit = LineItemUnit.piece,
    this.price,
    this.barcode,
    this.source = IngestionSource.freeText,
    this.purchasedAt,
    this.matchedProductId,
    this.matchConfidence = 0,
    this.inferredShelfLifeDays,
    DateTime? registeredAt,
  }) : registeredAt = registeredAt ?? purchasedAt,
       assert(quantity > 0, 'quantity must be positive');

  final String id;
  final String rawName;
  final String normalizedName;

  final double quantity;
  final LineItemUnit unit;
  final double? price;
  final String? barcode;

  final IngestionSource source;
  final DateTime? purchasedAt;

  /// When the item entered the system; falls back to [purchasedAt].
  final DateTime? registeredAt;

  /// Product the item was matched to, if any.
  final String? matchedProductId;

  /// 0..1 similarity between the normalized name and the matched product.
  final double matchConfidence;

  /// Category-based default shelf life in days, if inferred.
  final int? inferredShelfLifeDays;

  /// Returns a copy with the given fields replaced.
  LineItem copyWith({
    String? rawName,
    String? normalizedName,
    double? quantity,
    LineItemUnit? unit,
    double? price,
    String? barcode,
    IngestionSource? source,
    DateTime? purchasedAt,
    String? matchedProductId,
    double? matchConfidence,
    int? inferredShelfLifeDays,
  }) => LineItem(
    id: id,
    rawName: rawName ?? this.rawName,
    normalizedName: normalizedName ?? this.normalizedName,
    quantity: quantity ?? this.quantity,
    unit: unit ?? this.unit,
    price: price ?? this.price,
    barcode: barcode ?? this.barcode,
    source: source ?? this.source,
    purchasedAt: purchasedAt ?? this.purchasedAt,
    matchedProductId: matchedProductId ?? this.matchedProductId,
    matchConfidence: matchConfidence ?? this.matchConfidence,
    inferredShelfLifeDays: inferredShelfLifeDays ?? this.inferredShelfLifeDays,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LineItem &&
          other.id == id &&
          other.rawName == rawName &&
          other.normalizedName == normalizedName &&
          other.quantity == quantity &&
          other.unit == unit &&
          other.price == price &&
          other.barcode == barcode &&
          other.source == source &&
          other.purchasedAt == purchasedAt &&
          other.registeredAt == registeredAt &&
          other.matchedProductId == matchedProductId &&
          other.matchConfidence == matchConfidence &&
          other.inferredShelfLifeDays == inferredShelfLifeDays;

  @override
  int get hashCode => Object.hash(
    id,
    rawName,
    normalizedName,
    quantity,
    unit,
    price,
    barcode,
    source,
    purchasedAt,
    registeredAt,
    matchedProductId,
    matchConfidence,
    inferredShelfLifeDays,
  );

  @override
  String toString() =>
      'LineItem($rawName x$quantity ${unit.name}, match: '
      '${matchedProductId != null ? '$matchConfidence' : 'none'})';
}
