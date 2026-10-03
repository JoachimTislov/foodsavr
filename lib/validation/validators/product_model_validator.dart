import 'package:foodsavr/interfaces/i_validator.dart';
import 'package:foodsavr/models/product_model.dart';
import 'package:foodsavr/validation/validation_error.dart';
import 'package:foodsavr/validation/validation_result.dart';

class ProductModelValidator implements IValidator<Product> {
  @override
  ValidationResult validate(Product instance) {
    final errors = <ValidationError>[];

    if (instance.name.trim().isEmpty) {
      errors.add(
        const ValidationError(
          field: 'name',
          message: 'Product name cannot be empty',
        ),
      );
    }

    if (instance.nonExpiringQuantity < 0) {
      errors.add(
        const ValidationError(
          field: 'nonExpiringQuantity',
          message: 'Non-expiring quantity cannot be negative',
        ),
      );
    }

    for (var i = 0; i < instance.expiries.length; i++) {
      final expiryEntry = instance.expiries[i];
      if (expiryEntry.quantity <= 0) {
        errors.add(
          ValidationError(
            field: 'expiries[$i].quantity',
            message: 'Expiry quantity must be positive',
          ),
        );
      }
      // expirationDate is a required DateTime, so it won't be null.
      // Further date validation (e.g., not in the past for new entries)
      // could be added here if business logic dictates.
    }

    // Additional validation for other fields like registryType could be added here
    // if there's a predefined set of allowed values.

    return ValidationResult(errors);
  }
}
