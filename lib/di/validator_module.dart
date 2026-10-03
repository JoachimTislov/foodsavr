import 'package:injectable/injectable.dart';
import 'package:foodsavr/interfaces/i_validator.dart';
import 'package:foodsavr/models/collection_model.dart';
import 'package:foodsavr/models/product_model.dart';
import 'package:foodsavr/validation/validators/collection_model_validator.dart';
import 'package:foodsavr/validation/validators/product_model_validator.dart';

@module
abstract class ValidatorModule {
  @lazySingleton
  IValidator<Collection> get collectionValidator => CollectionModelValidator();

  @lazySingleton
  IValidator<Product> get productValidator => ProductModelValidator();
}
