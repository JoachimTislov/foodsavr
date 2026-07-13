import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import '../../models/product_model.dart';

class ExpiriesSection extends StatelessWidget {
  final List<ExpiryEntry> expiries;
  final VoidCallback onAdd;
  final ValueChanged<int> onRemove;

  const ExpiriesSection({
    super.key,
    required this.expiries,
    required this.onAdd,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'product.expiries'.tr(),
              style: Theme.of(context).textTheme.titleSmall,
            ),
            TextButton.icon(
              icon: const Icon(Icons.add),
              label: Text('product.add_expiry'.tr()),
              onPressed: onAdd,
            ),
          ],
        ),
        ...expiries.asMap().entries.map((entry) {
          final idx = entry.key;
          final expiry = entry.value;
          return ListTile(
            title: Text(DateFormat.yMMMd().format(expiry.expirationDate)),
            subtitle: Text(
              'product.quantity_units'.tr(args: [expiry.quantity.toString()]),
            ),
            trailing: IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: () => onRemove(idx),
            ),
          );
        }),
      ],
    );
  }
}
