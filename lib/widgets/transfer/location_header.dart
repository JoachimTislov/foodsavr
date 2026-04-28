import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../product/compact_location_card.dart';

class LocationHeader extends StatelessWidget {
  final String fromLocationName;
  final String toLocationName;

  const LocationHeader({
    super.key,
    required this.fromLocationName,
    required this.toLocationName,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainer,
        border: Border(
          bottom: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.1),
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: CompactLocationCard(
              label: 'common.from'.tr(),
              locationName: fromLocationName,
              isActive: true,
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8),
            child: Icon(Icons.arrow_forward, size: 16),
          ),
          Expanded(
            child: CompactLocationCard(
              label: 'common.to'.tr(),
              locationName: toLocationName,
              isActive: false,
            ),
          ),
        ],
      ),
    );
  }
}
