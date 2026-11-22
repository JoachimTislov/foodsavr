import 'package:foodsavr_core/foodsavr_core.dart';
import 'package:injectable/injectable.dart';

import '../models/product_model.dart';

@lazySingleton
class ShelfLifeService {
  final _inferer = ShelfLifeInferer();

  /// Estimates an expiration date from product tags or category.
  DateTime? estimateExpiration(Product product, {DateTime? addedDate}) {
    final estimate = _inferer.estimate(
      tags: product.tags,
      category: product.category,
    );
    if (estimate == null) return null;
    return (addedDate ?? DateTime.now()).add(Duration(days: estimate.days));
  }
}
