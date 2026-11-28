import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../controllers/batch_expiry_controller.dart';

/// The expiries saved so far in a batch session, newest first.
class RegisteredExpiryList extends StatelessWidget {
  final List<RegisteredExpiry> items;

  const RegisteredExpiryList({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    final format = DateFormat.yMMMd(context.locale.toString());
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'batchExpiry.registered'.tr(),
          style: Theme.of(context).textTheme.titleMedium,
        ),
        for (final item in items)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(
              Icons.check_circle_outline,
              color: Theme.of(context).colorScheme.primary,
            ),
            title: Text(item.name),
            subtitle: Text(
              'batchExpiry.registeredItem'.tr(
                namedArgs: {
                  'quantity': '${item.quantity}',
                  'date': format.format(item.date),
                },
              ),
            ),
          ),
      ],
    );
  }
}
