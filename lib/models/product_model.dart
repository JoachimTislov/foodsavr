import 'package:flutter/material.dart';

/// Product status based on expiration date
enum ProductStatus {
  fresh,
  expiringSoon,
  expired;

  /// Get status color for the given color scheme
  Color getColor(ColorScheme colorScheme) {
    switch (this) {
      case ProductStatus.fresh:
        return colorScheme.primary;
      case ProductStatus.expiringSoon:
        return colorScheme.tertiary;
      case ProductStatus.expired:
        return colorScheme.error;
    }
  }

  /// Get status message
  String getMessage() {
    switch (this) {
      case ProductStatus.fresh:
        return 'Fresh';
      case ProductStatus.expiringSoon:
        return 'Expires Soon';
      case ProductStatus.expired:
        return 'Expired';
    }
  }

  /// Get status icon
  IconData getIcon() {
    switch (this) {
      case ProductStatus.fresh:
        return Icons.check_circle_outline;
      case ProductStatus.expiringSoon:
        return Icons.warning_amber_rounded;
      case ProductStatus.expired:
        return Icons.error_outline;
    }
  }
}

class Product {
  final int id;
  final String name;
  final String description;
  final String userId; // Owner of the product
  final DateTime? expirationDate; // When the product expires
  final int quantity; // Quantity available
  final String? category; // Category (e.g., 'Dairy', 'Fruits', 'Vegetables')
  final String? imageUrl; // Optional image URL
  final bool isGlobal; // True if product is in global catalog

  Product({
    required this.id,
    required this.name,
    required this.description,
    required this.userId,
    this.expirationDate,
    this.quantity = 1,
    this.category,
    this.imageUrl,
    this.isGlobal = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'userId': userId,
      'expirationDate': expirationDate?.toIso8601String(),
      'quantity': quantity,
      'category': category,
      'imageUrl': imageUrl,
      'isGlobal': isGlobal,
    };
  }

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id'] as int,
      name: json['name'] as String,
      description: json['description'] as String,
      userId: json['userId'] as String,
      expirationDate: json['expirationDate'] != null
          ? DateTime.parse(json['expirationDate'] as String)
          : null,
      quantity: json['quantity'] as int? ?? 1,
      category: json['category'] as String?,
      imageUrl: json['imageUrl'] as String?,
      isGlobal: json['isGlobal'] as bool? ?? false,
    );
  }

  // Helper method to check if product is expired
  bool get isExpired {
    if (expirationDate == null) return false;
    return expirationDate!.isBefore(DateTime.now());
  }

  // Helper method to check if product is expiring soon (within 1–3 days)
  bool get isExpiringSoon {
    if (expirationDate == null) return false;
    final difference = expirationDate!.difference(DateTime.now());
    final daysUntilExpiration = difference.inDays;
    // Exclude products expiring today (daysUntilExpiration == 0) from "soon"
    if (difference.isNegative || daysUntilExpiration == 0) {
      return false;
    }
    return daysUntilExpiration <= 3;
  }

  // Days until expiration (negative if expired)
  int? get daysUntilExpiration {
    if (expirationDate == null) return null;
    return expirationDate!.difference(DateTime.now()).inDays;
  }

  // Get product status based on expiration
  ProductStatus get status {
    if (isExpired) return ProductStatus.expired;
    if (isExpiringSoon) return ProductStatus.expiringSoon;
    return ProductStatus.fresh;
  }
}
