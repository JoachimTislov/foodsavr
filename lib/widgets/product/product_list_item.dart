import 'package:flutter/material.dart';

import '../../models/product_model.dart';

class ProductListItem extends StatelessWidget {
  final Product product;

  const ProductListItem({super.key, required this.product});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ListTile(
        title: Text(product.name),
        subtitle: Text(product.description),
        // Add more details or actions here if needed
      ),
    );
  }
}
