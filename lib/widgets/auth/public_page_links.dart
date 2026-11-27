import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../constants/public_routes.dart';

class PublicPageLinks extends StatelessWidget {
  const PublicPageLinks({super.key, this.showLegalLinks = true});

  /// False where the legal documents are already linked.
  final bool showLegalLinks;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      children: [
        if (showLegalLinks) ...[
          TextButton(
            onPressed: () => context.push(PublicRoutes.privacy),
            child: Text('common.privacy_notice'.tr()),
          ),
          TextButton(
            onPressed: () => context.push(PublicRoutes.terms),
            child: Text('common.terms_of_service'.tr()),
          ),
        ],
        TextButton(
          onPressed: () => context.push(PublicRoutes.deleteAccount),
          child: Text('profile.delete_account'.tr()),
        ),
      ],
    );
  }
}
