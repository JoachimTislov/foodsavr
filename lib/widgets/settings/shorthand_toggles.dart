import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../service_locator.dart';
import '../../utils/app_locales.dart';
import '../../utils/theme_notifier.dart';
import 'segmented_pill.dart';

/// Switches the app language between Norwegian and English in one tap.
class LanguageTogglePill extends StatelessWidget {
  const LanguageTogglePill({super.key});

  @override
  Widget build(BuildContext context) {
    return SegmentedPill<String>(
      segments: [
        (
          value: nbLocale.languageCode,
          label: 'NO',
          icon: null,
          semanticLabel: 'settings.languages.nb'.tr(),
        ),
        (
          value: enLocale.languageCode,
          label: 'EN',
          icon: null,
          semanticLabel: 'settings.languages.en'.tr(),
        ),
      ],
      selected: context.locale.languageCode,
      onSelected: (code) => context.setLocale(Locale(code)),
    );
  }
}

/// Switches between the light, system and dark theme in one tap.
class ThemeTogglePill extends StatelessWidget {
  final ThemeNotifier? notifier;

  const ThemeTogglePill({super.key, this.notifier});

  @override
  Widget build(BuildContext context) {
    final theme = notifier ?? getIt<ThemeNotifier>();
    // Rebuilds the translated labels when the language changes.
    context.locale;
    return ListenableBuilder(
      listenable: theme,
      builder: (context, _) => SegmentedPill<ThemeMode>(
        segments: [
          (
            value: ThemeMode.light,
            label: null,
            icon: Icons.light_mode,
            semanticLabel: 'settings.themes.light'.tr(),
          ),
          (
            value: ThemeMode.system,
            label: null,
            icon: Icons.brightness_auto,
            semanticLabel: 'settings.themes.system'.tr(),
          ),
          (
            value: ThemeMode.dark,
            label: null,
            icon: Icons.dark_mode,
            semanticLabel: 'settings.themes.dark'.tr(),
          ),
        ],
        selected: theme.themeMode,
        onSelected: theme.setTheme,
      ),
    );
  }
}
