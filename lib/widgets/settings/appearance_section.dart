import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../utils/theme_notifier.dart';
import 'settings_action_row.dart';
import 'settings_section.dart';
import 'shorthand_toggles.dart';

/// Theme and language, each switched with a shorthand toggle.
class AppearanceSection extends StatelessWidget {
  final ThemeNotifier themeNotifier;

  const AppearanceSection({super.key, required this.themeNotifier});

  @override
  Widget build(BuildContext context) {
    final language = context.locale.languageCode == 'en'
        ? 'settings.languages.en'.tr()
        : 'settings.languages.nb'.tr();

    return SettingsSection(
      title: 'settings.appearance'.tr(),
      children: [
        ListenableBuilder(
          listenable: themeNotifier,
          builder: (context, _) => SettingsActionRow(
            stackBelow: 340,
            icon: Icons.dark_mode_outlined,
            title: 'settings.theme_mode'.tr(),
            subtitle: switch (themeNotifier.themeMode) {
              ThemeMode.system => 'settings.themes.system'.tr(),
              ThemeMode.light => 'settings.themes.light'.tr(),
              ThemeMode.dark => 'settings.themes.dark'.tr(),
            },
            action: ThemeTogglePill(notifier: themeNotifier),
          ),
        ),
        SettingsActionRow(
          stackBelow: 340,
          icon: Icons.language_outlined,
          title: 'settings.language'.tr(),
          subtitle: language,
          action: LanguageTogglePill(),
        ),
      ],
    );
  }
}
