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

/// Entry for a specific quantity expiring on a specific date
class ExpiryEntry {
  final int quantity;
  final DateTime expirationDate;

  ExpiryEntry({required this.quantity, required this.expirationDate});

  Map<String, dynamic> toJson() {
    return {
      'quantity': quantity,
      'expirationDate': expirationDate.toIso8601String(),
    };
  }

  factory ExpiryEntry.fromJson(Map<String, dynamic> json) {
    return ExpiryEntry(
      quantity: json['quantity'] as int,
      expirationDate: DateTime.parse(json['expirationDate'] as String),
    );
  }

  bool get isExpired {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final expiry = DateTime(
      expirationDate.year,
      expirationDate.month,
      expirationDate.day,
    );
    return expiry.isBefore(today);
  }

  bool get isExpiringToday {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final expiry = DateTime(
      expirationDate.year,
      expirationDate.month,
      expirationDate.day,
    );
    return expiry.isAtSameMomentAs(today);
  }

  int get daysUntilExpiration {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final expiry = DateTime(
      expirationDate.year,
      expirationDate.month,
      expirationDate.day,
    );
    return expiry.difference(today).inDays;
  }
}

class Product {
  final int id;
  final String name;
  final String description;
  final String userId; // Owner of the product
  final List<ExpiryEntry> expiries; // Quantities and their expiration dates
  final String? category; // Category (e.g., 'Dairy', 'Fruits', 'Vegetables')
  final String? imageUrl; // Optional image URL
  final bool isGlobal; // True if product is in global catalog

  Product({
    required this.id,
    required this.name,
    required this.description,
    required this.userId,
    this.expiries = const [],
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
      'expiries': expiries.map((e) => e.toJson()).toList(),
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
      expiries:
          (json['expiries'] as List<dynamic>?)
              ?.map((e) => ExpiryEntry.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      category: json['category'] as String?,
      imageUrl: json['imageUrl'] as String?,
      isGlobal: json['isGlobal'] as bool? ?? false,
    );
  }

  // Helper method to get total quantity
  int get quantity => expiries.fold(0, (sum, entry) => sum + entry.quantity);

  // Helper method to get the soonest expiration date
  DateTime? get soonestExpirationDate {
    if (expiries.isEmpty) return null;
    return expiries
        .map((e) => e.expirationDate)
        .reduce((a, b) => a.isBefore(b) ? a : b);
  }

  // Helper method to check if any quantity is expired
  bool get isExpired {
    return expiries.any((e) => e.isExpired);
  }

  // Helper method to check if any quantity is expiring today
  bool get isExpiringToday {
    return expiries.any((e) => e.isExpiringToday);
  }

  // Helper method to check if any quantity is expiring soon (within 1–6 days)
  bool get isExpiringSoon {
    return expiries.any((e) {
      final days = e.daysUntilExpiration;
      return days > 0 && days <= 6;
    });
  }

  // Soonest days until expiration (negative if expired)
  int? get daysUntilExpiration {
    if (expiries.isEmpty) return null;
    return expiries
        .map((e) => e.daysUntilExpiration)
        .reduce((a, b) => a < b ? a : b);
  }

  // Get product status based on expiration
  ProductStatus get status {
    if (isExpired) return ProductStatus.expired;
    if (isExpiringToday || isExpiringSoon) return ProductStatus.expiringSoon;
    return ProductStatus.fresh;
  }
}
