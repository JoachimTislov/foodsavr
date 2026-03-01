import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../interfaces/i_auth_service.dart';
import '../service_locator.dart';
import '../services/theme_notifier.dart';

class SettingsView extends StatefulWidget {
  const SettingsView({super.key});

  @override
  State<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<SettingsView> {
  late final IAuthService _authService;

  @override
  void initState() {
    super.initState();
    _authService = getIt<IAuthService>();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/products');
            }
          },
        ),
        title: Text(
          'settings.title'.tr(),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // User Profile Section (Mocked)
            _SettingsSection(
              title: 'settings.account'.tr(),
              children: [
                _SettingsTile(
                  leading: CircleAvatar(
                    radius: 20,
                    backgroundColor: Theme.of(
                      context,
                    ).colorScheme.primaryContainer,
                    child: Icon(
                      Icons.person_outline,
                      size: 20,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ),
                  title: 'generated.janeDoe'.tr(),
                  subtitle: 'generated.janedoepantrypalcom'.tr(),
                  onTap: () => context.push('/profile'),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Appearance Section
            _SettingsSection(
              title: 'settings.appearance'.tr(),
              children: [
                _SettingsTile(
                  icon: Icons.dark_mode_outlined,
                  title: 'settings.theme_mode'.tr(),
                  trailing: Text(
                    'settings.themes.system'.tr(),
                    style: textTheme.bodyMedium?.copyWith(
                      color: colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  onTap: () => _showThemeSelector(context),
                ),
                _SettingsTile(
                  icon: Icons.language_outlined,
                  title: 'settings.language'.tr(),
                  trailing: Text(
                    context.locale.languageCode == 'en'
                        ? 'settings.languages.en'.tr()
                        : 'settings.languages.nb'.tr(),
                    style: textTheme.bodyMedium?.copyWith(
                      color: colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  onTap: () => _showLanguageSelector(context),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Legal & Info Section
            _SettingsSection(
              title: 'settings.about'.tr(),
              children: [
                _SettingsTile(
                  icon: Icons.description_outlined,
                  title: 'settings.terms_of_service'.tr(),
                  onTap: () {},
                ),
                _SettingsTile(
                  icon: Icons.privacy_tip_outlined,
                  title: 'settings.privacy_policy'.tr(),
                  onTap: () {},
                ),
                _SettingsTile(
                  icon: Icons.info_outline,
                  title: 'settings.app_version'.tr(),
                  trailing: Text('generated.100_42'.tr()),
                  onTap: null,
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Danger Zone Section
            _SettingsSection(
              title: 'settings.danger_zone'.tr(),
              isDanger: true,
              children: [
                _SettingsTile(
                  icon: Icons.delete_outline,
                  title: 'settings.delete_account'.tr(),
                  subtitle: 'settings.delete_account_description'.tr(),
                  isDanger: true,
                  onTap: () => _showDeleteAccountConfirmation(context),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteAccountConfirmation(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 24),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Icon(
              Icons.warning_amber_rounded,
              color: Colors.red,
              size: 48,
            ),
            const SizedBox(height: 16),
            Text(
              'settings.delete_account'.tr(),
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(
              'settings.delete_account_description'.tr(),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              // TODO(profile): Call _authService.deleteAccount() once implemented in IAuthService
              onPressed: () async {
                Navigator.pop(context);
                _authService.signOut();
              },
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(56),
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Text('profile.deleteAccountConfirmation'.tr()),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => Navigator.pop(context),
              style: TextButton.styleFrom(
                minimumSize: const Size.fromHeight(56),
              ),
              child: Text('common.cancel'.tr()),
            ),
          ],
        ),
      ),
    );
  }

  void _showThemeSelector(BuildContext context) {
    final themeNotifier = getIt<ThemeNotifier>();
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.brightness_auto),
              title: Text('settings.themes.system'.tr()),
              onTap: () {
                themeNotifier.setTheme(ThemeMode.system);
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.light_mode),
              title: Text('settings.themes.light'.tr()),
              onTap: () {
                themeNotifier.setTheme(ThemeMode.light);
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.dark_mode),
              title: Text('settings.themes.dark'.tr()),
              onTap: () {
                themeNotifier.setTheme(ThemeMode.dark);
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showLanguageSelector(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text('settings.languages.en'.tr()),
              trailing: context.locale.languageCode == 'en'
                  ? const Icon(Icons.check, color: Colors.blue)
                  : null,
              onTap: () {
                context.setLocale(const Locale('en', 'US'));
                Navigator.pop(context);
              },
            ),
            ListTile(
              title: Text('settings.languages.nb'.tr()),
              trailing: context.locale.languageCode == 'nb'
                  ? const Icon(Icons.check, color: Colors.blue)
                  : null,
              onTap: () {
                context.setLocale(const Locale('nb', 'NO'));
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsSection extends StatelessWidget {
  final String title;
  final List<Widget> children;
  final bool isDanger;

  const _SettingsSection({
    required this.title,
    required this.children,
    this.isDanger = false,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 8, bottom: 8),
          child: Text(
            title.toUpperCase(),
            style: textTheme.labelSmall?.copyWith(
              color: isDanger ? Colors.red : colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainer,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: colorScheme.outlineVariant.withValues(alpha: 0.1),
            ),
          ),
          child: Column(
            children: [
              for (int i = 0; i < children.length; i++) ...[
                if (i > 0)
                  Divider(
                    height: 1,
                    indent: 56,
                    endIndent: 16,
                    color: colorScheme.outlineVariant.withValues(alpha: 0.1),
                  ),
                children[i],
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final Widget? leading;
  final IconData? icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool isDanger;

  const _SettingsTile({
    this.leading,
    this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.isDanger = false,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return ListTile(
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      leading:
          leading ??
          (icon == null
              ? null
              : Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isDanger
                        ? Colors.red.withValues(alpha: 0.1)
                        : colorScheme.primaryContainer.withValues(alpha: 0.5),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icon,
                    size: 20,
                    color: isDanger ? Colors.red : colorScheme.primary,
                  ),
                )),
      title: Text(
        title,
        style: textTheme.bodyLarge?.copyWith(
          fontWeight: FontWeight.w600,
          color: isDanger ? Colors.red : null,
        ),
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle!,
              style: textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            )
          : null,
      trailing: trailing,
    );
  }
}
