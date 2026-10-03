import 'package:foodsavr/interfaces/i_validator.dart';
import 'package:foodsavr/models/collection_model.dart';
import 'package:foodsavr/validation/validation_error.dart';
import 'package:foodsavr/validation/validation_result.dart';

class CollectionModelValidator implements IValidator<Collection> {
  @override
  ValidationResult validate(Collection instance) {
    final errors = <ValidationError>[];

    if (instance.name.trim().isEmpty) {
      errors.add(
        const ValidationError(
          field: 'name',
          message: 'Collection name cannot be empty',
        ),
      );
    }

    // `productIds` is a required field and List<String>, so it won't be null
    // due to Dart's null safety and the model definition.
    // However, if we wanted to enforce it's not an empty list:
    // if (instance.productIds.isEmpty) {
    //   errors.add(const ValidationError(
    //     field: 'productIds',
    //     message: 'Collection must contain at least one product',
    //   ));
    // }

    return ValidationResult(errors);
  }
}
