import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../models/receipt_record.dart';

/// One compact receipt row: store, date and item count.
class ReceiptListTile extends StatelessWidget {
  const ReceiptListTile({super.key, required this.record, required this.onTap});

  final ReceiptRecord record;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final date = DateFormat.yMMMd(
      context.locale.toString(),
    ).format(record.purchaseDate ?? record.occurredAt);
    return ListTile(
      leading: const Icon(Icons.receipt_long_outlined),
      title: Text(record.store ?? 'receipt.unknownStore'.tr()),
      subtitle: Text(date),
      trailing: Text(
        'receipt.items'.tr(namedArgs: {'count': '${record.itemCount}'}),
      ),
      onTap: onTap,
    );
  }
}
