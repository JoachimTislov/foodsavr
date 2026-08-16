import 'package:flutter/foundation.dart';

/// Represents a single validation error.
@immutable
class ValidationError {
  /// The field that the validation error is associated with.
  final String field;

  /// A human-readable message describing the validation error.
  final String message;

  /// Creates a [ValidationError] instance.
  const ValidationError({required this.field, required this.message});

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is ValidationError &&
        other.field == field &&
        other.message == message;
  }

  @override
  int get hashCode => field.hashCode ^ message.hashCode;

  @override
  String toString() => 'ValidationError(field: $field, message: $message)';
}
