import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../constants/material3_config.dart';
import '../../models/receipt_record.dart';
import '../../service_locator.dart';
import '../../services/product_service.dart';

/// Bottom sheet with the details of one receipt and, where they still exist,
/// the names of its products.
class ReceiptDetailsSheet extends StatefulWidget {
  const ReceiptDetailsSheet({super.key, required this.record});

  final ReceiptRecord record;

  static Future<void> show(BuildContext context, ReceiptRecord record) =>
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (_) => ReceiptDetailsSheet(record: record),
      );

  @override
  State<ReceiptDetailsSheet> createState() => _ReceiptDetailsSheetState();
}

class _ReceiptDetailsSheetState extends State<ReceiptDetailsSheet> {
  late final Future<List<String>> _names = _loadNames();

  Future<List<String>> _loadNames() async {
    final products = getIt<ProductService>();
    final names = <String>[];
    for (final id in widget.record.productIds) {
      try {
        final product = await products.getProductById(id);
        if (product != null) names.add(product.name);
      } catch (_) {
        // A product that cannot be resolved is left out of the list.
      }
    }
    return names;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final record = widget.record;
    final locale = context.locale.toString();
    final date = DateFormat.yMMMMd(
      locale,
    ).format(record.purchaseDate ?? record.occurredAt);
    final count = 'receipt.items'.tr(
      namedArgs: {'count': '${record.itemCount}'},
    );
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          Material3Config.spacing24,
          0,
          Material3Config.spacing24,
          Material3Config.spacing16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              record.store ?? 'receipt.unknownStore'.tr(),
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: Material3Config.spacing4),
            Text(
              '$date · $count',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            FutureBuilder<List<String>>(
              future: _names,
              builder: (context, snapshot) {
                final names = snapshot.data ?? const <String>[];
                if (names.isEmpty) return const SizedBox.shrink();
                return Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    padding: const EdgeInsets.only(
                      top: Material3Config.spacing12,
                    ),
                    children: [
                      for (final name in names)
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: Material3Config.spacing4,
                          ),
                          child: Text(name),
                        ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
