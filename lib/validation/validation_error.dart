import 'package:flutter/foundation.dart';

/// Stable identifiers for validation failures, localized for display.
enum ValidationCode {
  productNameEmpty,
  nonExpiringQuantityNegative,
  expiryQuantityNotPositive,
  collectionNameEmpty,
}

/// Represents a single validation error.
@immutable
class ValidationError {
  /// The field that the validation error is associated with.
  final String field;

  /// A developer-facing message describing the validation error, for logs.
  final String message;

  /// Identifies the failure for localized display; null when unmapped.
  final ValidationCode? code;

  /// Creates a [ValidationError] instance.
  const ValidationError({
    required this.field,
    required this.message,
    this.code,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is ValidationError &&
        other.field == field &&
        other.message == message &&
        other.code == code;
  }

  @override
  int get hashCode => Object.hash(field, message, code);

  @override
  String toString() => 'ValidationError(field: $field, message: $message)';
}

/// Thrown when a model fails validation before it is persisted.
class ValidationException extends FormatException {
  /// The first validation failure.
  final ValidationError error;

  ValidationException(this.error) : super(error.message);
}
