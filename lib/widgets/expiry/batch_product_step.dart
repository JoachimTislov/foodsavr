import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../controllers/batch_expiry_controller.dart';

/// First step of a batch session: scan a product, find one of the user's own,
/// or start a new one by typing its name.
class BatchProductStep extends StatefulWidget {
  final BatchExpiryController controller;

  /// Null when the device cannot scan barcodes.
  final VoidCallback? onScan;

  const BatchProductStep({super.key, required this.controller, this.onScan});

  @override
  State<BatchProductStep> createState() => _BatchProductStepState();
}

class _BatchProductStepState extends State<BatchProductStep> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final matches = controller.matches(_query);
    final typed = _query.trim();
    final exact = matches.any(
      (product) => product.name.toLowerCase() == typed.toLowerCase(),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.onScan != null) ...[
          FilledButton.tonalIcon(
            onPressed: widget.onScan,
            icon: const Icon(Icons.qr_code_scanner),
            label: Text('batchExpiry.scanProduct'.tr()),
          ),
          const SizedBox(height: 16),
        ],
        TextField(
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.search),
            hintText: 'batchExpiry.search'.tr(),
          ),
          onChanged: (value) => setState(() => _query = value),
        ),
        for (final product in matches.take(8))
          ListTile(
            leading: const Icon(Icons.inventory_2_outlined),
            title: Text(product.name),
            onTap: () => controller.select(product),
          ),
        if (typed.isNotEmpty && !exact)
          ListTile(
            leading: const Icon(Icons.add_circle_outline),
            title: Text('batchExpiry.createNew'.tr(namedArgs: {'name': typed})),
            onTap: () => controller.startNew(typed),
          ),
        if (typed.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Text(
              'batchExpiry.noProducts'.tr(),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
      ],
    );
  }
}
