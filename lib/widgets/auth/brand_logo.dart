import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../utils/app_theme.dart';

/// The LettMat leaf badge and wordmark.
class BrandLogo extends StatelessWidget {
  const BrandLogo({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AppTheme.brandColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.eco, color: AppTheme.onBrandColor, size: 26),
        ),
        const SizedBox(width: 12),
        Text(
          'auth.brand'.tr(),
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
        ),
      ],
    );
  }
}
