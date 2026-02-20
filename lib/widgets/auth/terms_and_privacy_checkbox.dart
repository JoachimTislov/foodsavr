import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

class TermsAndPrivacyCheckbox extends StatelessWidget {
  final bool value;
  final ValueChanged<bool?> onChanged;
  final TapGestureRecognizer privacyRecognizer;
  final TapGestureRecognizer termsRecognizer;

  const TermsAndPrivacyCheckbox({
    super.key,
    required this.value,
    required this.onChanged,
    required this.privacyRecognizer,
    required this.termsRecognizer,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Checkbox(value: value, onChanged: onChanged),
        Expanded(
          child: RichText(
            text: TextSpan(
              text: 'auth_agree_prefix'.tr(),
              style: Theme.of(context).textTheme.bodySmall,
              children: [
                TextSpan(
                  text: 'common_privacy_notice'.tr(),
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                  recognizer: privacyRecognizer,
                ),
                TextSpan(
                  text: 'common_and'.tr(),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                TextSpan(
                  text: 'common_terms_of_service'.tr(),
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                  recognizer: termsRecognizer,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
