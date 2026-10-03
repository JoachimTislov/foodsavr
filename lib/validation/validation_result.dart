import 'package:flutter/foundation.dart';
import 'package:foodsavr/validation/validation_error.dart';

/// Represents the result of a validation operation,
/// containing a list of errors if validation failed.
@immutable
class ValidationResult {
  final List<ValidationError> errors;

  /// True if there are no errors, false otherwise.
  bool get isValid => errors.isEmpty;

  /// Creates a [ValidationResult] instance with a list of errors.
  const ValidationResult(this.errors);

  /// Creates a successful [ValidationResult] with no errors.
  factory ValidationResult.success() => const ValidationResult([]);

  /// Creates a failed [ValidationResult] with a single error.
  factory ValidationResult.failure(ValidationError error) =>
      ValidationResult([error]);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is ValidationResult && listEquals(other.errors, errors);
  }

  @override
  int get hashCode => errors.hashCode;

  @override
  String toString() => 'ValidationResult(errors: $errors)';
}
