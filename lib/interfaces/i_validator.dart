import 'package:foodsavr/validation/validation_result.dart';

/// Defines the contract for a validator that validates instances of type [T].
abstract interface class IValidator<T> {
  /// Validates the given [instance] and returns a [ValidationResult].
  ///
  /// The [ValidationResult] will contain a list of [ValidationError] if any
  /// validation rules are violated. If the instance is valid, the result
  /// will have an empty list of errors.
  ValidationResult validate(T instance);
}
