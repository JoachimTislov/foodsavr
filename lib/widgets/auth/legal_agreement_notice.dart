import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../constants/public_routes.dart';

/// States that signing in or creating an account accepts the legal documents.
class LegalAgreementNotice extends StatefulWidget {
  const LegalAgreementNotice({super.key, required this.isLogin});

  final bool isLogin;

  @override
  State<LegalAgreementNotice> createState() => _LegalAgreementNoticeState();
}

class _LegalAgreementNoticeState extends State<LegalAgreementNotice> {
  late final _termsRecognizer = TapGestureRecognizer()
    ..onTap = () => context.push(PublicRoutes.terms);
  late final _privacyRecognizer = TapGestureRecognizer()
    ..onTap = () => context.push(PublicRoutes.privacy);

  @override
  void dispose() {
    _termsRecognizer.dispose();
    _privacyRecognizer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final linkStyle = TextStyle(
      color: theme.colorScheme.primary,
      fontWeight: FontWeight.bold,
    );

    return SizedBox(
      width: double.infinity,
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: widget.isLogin
                  ? 'auth.legal.sign_in_prefix'.tr()
                  : 'auth.legal.sign_up_prefix'.tr(),
            ),
            TextSpan(
              text: 'auth.legal.terms'.tr(),
              style: linkStyle,
              recognizer: _termsRecognizer,
            ),
            TextSpan(text: 'common.and'.tr()),
            TextSpan(
              text: 'auth.legal.privacy'.tr(),
              style: linkStyle,
              recognizer: _privacyRecognizer,
            ),
          ],
        ),
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}
