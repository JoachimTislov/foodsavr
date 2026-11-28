import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../utils/product_add_helper.dart';

/// Bottom sheet that captures an expiry date and quantity in one step.
class AddExpirySheet extends StatefulWidget {
  const AddExpirySheet({super.key});

  /// Returns the chosen date and quantity, or null when dismissed.
  static Future<({DateTime date, int quantity})?> show(BuildContext context) =>
      showModalBottomSheet<({DateTime date, int quantity})>(
        context: context,
        isScrollControlled: true,
        builder: (_) => const AddExpirySheet(),
      );

  @override
  State<AddExpirySheet> createState() => _AddExpirySheetState();
}

class _AddExpirySheetState extends State<AddExpirySheet> {
  DateTime? _date;
  int _quantity = 1;

  Future<void> _pickDate() async {
    final date = await ProductAddHelper.captureExpiryDate(context);
    if (date != null && mounted) setState(() => _date = date);
  }

  @override
  Widget build(BuildContext context) {
    final date = _date;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          24,
          16,
          24,
          16 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'product.addExpiry'.tr(),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _pickDate,
              icon: const Icon(Icons.event),
              label: Text(
                date == null
                    ? 'batchExpiry.setDate'.tr()
                    : DateFormat.yMMMd(context.locale.toString()).format(date),
              ),
            ),
            Row(
              children: [
                Expanded(child: Text('batchExpiry.quantity'.tr())),
                IconButton(
                  icon: const Icon(Icons.remove),
                  tooltip: 'batchExpiry.decrease'.tr(),
                  onPressed: _quantity > 1
                      ? () => setState(() => _quantity--)
                      : null,
                ),
                Text('$_quantity'),
                IconButton(
                  icon: const Icon(Icons.add),
                  tooltip: 'batchExpiry.increase'.tr(),
                  onPressed: () => setState(() => _quantity++),
                ),
              ],
            ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: date == null
                  ? null
                  : () => Navigator.of(
                      context,
                    ).pop((date: date, quantity: _quantity)),
              child: Text('common.add'.tr()),
            ),
          ],
        ),
      ),
    );
  }
}
