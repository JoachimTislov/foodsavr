import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

class QuantitySection extends StatelessWidget {
  final int quantity;
  final ValueChanged<int> onChanged;

  const QuantitySection({
    super.key,
    required this.quantity,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text('product.non_expiring_quantity'.tr()),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.remove),
            onPressed: quantity > 0 ? () => onChanged(quantity - 1) : null,
          ),
          Text(quantity.toString()),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => onChanged(quantity + 1),
          ),
        ],
      ),
    );
  }
}
