import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../controllers/batch_expiry_controller.dart';

/// Second step of a batch session: the chosen product, its expiry date and
/// quantity, and the save action.
class BatchExpiryStep extends StatelessWidget {
  final BatchExpiryController controller;
  final VoidCallback onPickDate;
  final VoidCallback onSave;

  const BatchExpiryStep({
    super.key,
    required this.controller,
    required this.onPickDate,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    final date = controller.date;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (controller.creating)
          TextFormField(
            key: ValueKey(controller.draftBarcode),
            initialValue: controller.draftName,
            autofocus: controller.draftName.isEmpty,
            decoration: InputDecoration(
              labelText: 'batchExpiry.newProduct'.tr(),
              suffixIcon: IconButton(
                icon: const Icon(Icons.close),
                tooltip: 'batchExpiry.change'.tr(),
                onPressed: controller.clearProduct,
              ),
            ),
            onChanged: controller.setName,
          )
        else
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.inventory_2_outlined),
            title: Text(controller.productName),
            trailing: IconButton(
              icon: const Icon(Icons.close),
              tooltip: 'batchExpiry.change'.tr(),
              onPressed: controller.clearProduct,
            ),
          ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: onPickDate,
          icon: const Icon(Icons.event),
          label: Text(
            date == null
                ? 'batchExpiry.setDate'.tr()
                : DateFormat.yMMMd(context.locale.toString()).format(date),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: Text('batchExpiry.quantity'.tr())),
            IconButton(
              icon: const Icon(Icons.remove),
              tooltip: 'batchExpiry.decrease'.tr(),
              onPressed: controller.quantity > 1
                  ? () => controller.setQuantity(controller.quantity - 1)
                  : null,
            ),
            Text('${controller.quantity}'),
            IconButton(
              icon: const Icon(Icons.add),
              tooltip: 'batchExpiry.increase'.tr(),
              onPressed: () => controller.setQuantity(controller.quantity + 1),
            ),
          ],
        ),
        const SizedBox(height: 8),
        FilledButton(
          onPressed: controller.canSave ? onSave : null,
          child: Text('batchExpiry.save'.tr()),
        ),
      ],
    );
  }
}
