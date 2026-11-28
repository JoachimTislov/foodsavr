import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../constants/material3_config.dart';
import '../../interfaces/i_auth_service.dart';
import '../../service_locator.dart';
import '../../utils/theme_notifier.dart';
import '../settings/shorthand_toggles.dart';
import 'desktop_logout_button.dart';

/// The horizontal task bar above the content on wide windows: language, theme
/// and logout. A control whose dependency is missing is left out.
class DesktopTaskBar extends StatelessWidget {
  /// Hidden where the page already offers the same toggles, as Settings does.
  final bool showPreferenceToggles;

  const DesktopTaskBar({super.key, this.showPreferenceToggles = true});

  @override
  Widget build(BuildContext context) {
    // The toggles read and change the locale.
    final showToggles =
        showPreferenceToggles && EasyLocalization.of(context) != null;

    return Material(
      color: Theme.of(context).colorScheme.surface,
      child: SafeArea(
        left: false,
        bottom: false,
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(minHeight: 64),
          padding: const EdgeInsets.symmetric(
            horizontal: Material3Config.spacing16,
            vertical: Material3Config.spacing8,
          ),
          alignment: AlignmentDirectional.centerEnd,
          child: Wrap(
            alignment: WrapAlignment.end,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: Material3Config.spacing12,
            runSpacing: Material3Config.spacing8,
            children: [
              if (showToggles) const LanguageTogglePill(),
              if (showToggles && getIt.isRegistered<ThemeNotifier>())
                const ThemeTogglePill(),
              if (getIt.isRegistered<IAuthService>())
                const DesktopLogoutButton(),
            ],
          ),
        ),
      ),
    );
  }
}
