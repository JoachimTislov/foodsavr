import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../utils/collection_types.dart';
import '../common/kickstart_card.dart';
import 'create_collection_button.dart';

/// The empty state for an account without collections or products.
class AccountKickstartCard extends StatelessWidget {
  final Future<void> Function() onCreated;

  const AccountKickstartCard({super.key, required this.onCreated});

  @override
  Widget build(BuildContext context) {
    return KickstartCard(
      icon: Icons.rocket_launch_outlined,
      title: 'kickstart.account.title'.tr(),
      message: 'kickstart.account.message'.tr(),
      actions: [
        CreateCollectionButton(
          type: CollectionType.inventory,
          onCreated: onCreated,
        ),
        CreateCollectionButton(
          type: CollectionType.shoppingList,
          onCreated: onCreated,
          tonal: true,
        ),
      ],
    );
  }
}
