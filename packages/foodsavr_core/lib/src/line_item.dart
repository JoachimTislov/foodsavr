/// Source of an ingested grocery line item.
enum LineItemSource { receipt, api, barcode, text }

/// One grocery item, normalized from any input source.
class LineItem {
  const LineItem({
    required this.rawName,
    this.normalizedName,
    required this.quantity,
    this.unit,
    this.price,
    required this.source,
    this.barcode,
    this.purchasedAt,
    this.productId,
    this.matchConfidence,
    this.category,
  });

  final String rawName;
  final String? normalizedName;
  final double quantity;
  final String? unit;
  final double? price;
  final LineItemSource source;
  final String? barcode;
  final DateTime? purchasedAt;
  final String? productId;
  final double? matchConfidence;
  final String? category;

  LineItem copyWith({
    String? rawName,
    String? normalizedName,
    double? quantity,
    String? unit,
    double? price,
    LineItemSource? source,
    String? barcode,
    DateTime? purchasedAt,
    String? productId,
    double? matchConfidence,
    String? category,
  }) {
    return LineItem(
      rawName: rawName ?? this.rawName,
      normalizedName: normalizedName ?? this.normalizedName,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      price: price ?? this.price,
      source: source ?? this.source,
      barcode: barcode ?? this.barcode,
      purchasedAt: purchasedAt ?? this.purchasedAt,
      productId: productId ?? this.productId,
      matchConfidence: matchConfidence ?? this.matchConfidence,
      category: category ?? this.category,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'rawName': rawName,
      'normalizedName': normalizedName,
      'quantity': quantity,
      'unit': unit,
      'price': price,
      'source': source.name,
      'barcode': barcode,
      'purchasedAt': purchasedAt?.toIso8601String(),
      'productId': productId,
      'matchConfidence': matchConfidence,
      'category': category,
    };
  }

  factory LineItem.fromJson(Map<String, dynamic> json) {
    return LineItem(
      rawName: json['rawName'] as String,
      normalizedName: json['normalizedName'] as String?,
      quantity: (json['quantity'] as num).toDouble(),
      unit: json['unit'] as String?,
      price: (json['price'] as num?)?.toDouble(),
      source: LineItemSource.values.firstWhere((s) => s.name == json['source']),
      barcode: json['barcode'] as String?,
      purchasedAt: json['purchasedAt'] == null
          ? null
          : DateTime.parse(json['purchasedAt'] as String),
      productId: json['productId'] as String?,
      matchConfidence: (json['matchConfidence'] as num?)?.toDouble(),
      category: json['category'] as String?,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LineItem &&
          rawName == other.rawName &&
          normalizedName == other.normalizedName &&
          quantity == other.quantity &&
          unit == other.unit &&
          price == other.price &&
          source == other.source &&
          barcode == other.barcode &&
          purchasedAt == other.purchasedAt &&
          productId == other.productId &&
          matchConfidence == other.matchConfidence &&
          category == other.category;

  @override
  int get hashCode => Object.hash(
    rawName,
    normalizedName,
    quantity,
    unit,
    price,
    source,
    barcode,
    purchasedAt,
    productId,
    matchConfidence,
    category,
  );
}
