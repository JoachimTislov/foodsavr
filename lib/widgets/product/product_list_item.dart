import 'package:flutter/material.dart';

import '../../models/product_model.dart';
import 'product_icon.dart';

class ProductListItem extends StatelessWidget {
  final Product product;

  const ProductListItem({super.key, required this.product});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ListTile(
        leading: ProductIcon.fromProduct(product, size: 40),
        title: Text(product.name),
        subtitle: product.description.isNotEmpty
            ? Text(product.description)
            : null,
      ),
    );
  }
}
