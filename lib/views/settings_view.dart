import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class SettingsView extends StatefulWidget {
  const SettingsView({super.key});

  @override
  State<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<SettingsView> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
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
                  leading: const CircleAvatar(
                    radius: 20,
                    backgroundImage: NetworkImage(
                      'https://lh3.googleusercontent.com/aida-public/AB6AXuDwWMgdYu2bPbsZUzBnp79nL40ENwB92gxV_m2tBlAkF0GGsbIPvV13lQsCLn5FLv1NVV6sdsRgRli8enFcLGbfiYaLIjBJkhK0VmLsrja29MeKUoZzZQjJHlExYCNQ7OjC2ztEXPs6s5RdUQ6nLoFf7baUhjxTRFzBnTXni8mYGRb13_k0110FqejEe84HVZvQlRVl9rm8tWZm9phi12hrKvZ03xmmHV9B1ySaoe35wCB3pnjwxqSfEkZVbtS0bKwI_7tyRLrRQXMC',
                    ),
                  ),
                  title: 'generated.janeDoe'.tr(),
                  subtitle: 'generated.janedoepantrypalcom'.tr(),
                  onTap: () => context.push('generated.profile'.tr()),
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
                    context.locale.languageCode == 'generated.en'.tr()
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
                  trailing: const Text('generated.100_42'.tr()),
                  onTap: null,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showThemeSelector(BuildContext context) {
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
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              leading: const Icon(Icons.light_mode),
              title: Text('settings.themes.light'.tr()),
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              leading: const Icon(Icons.dark_mode),
              title: Text('settings.themes.dark'.tr()),
              onTap: () => Navigator.pop(context),
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
              trailing: context.locale.languageCode == 'generated.en'.tr()
                  ? const Icon(Icons.check, color: Colors.blue)
                  : null,
              onTap: () {
                context.setLocale(const Locale('generated.en'.tr(), 'generated.us'.tr()));
                Navigator.pop(context);
              },
            ),
            ListTile(
              title: Text('settings.languages.nb'.tr()),
              trailing: context.locale.languageCode == 'generated.nb'.tr()
                  ? const Icon(Icons.check, color: Colors.blue)
                  : null,
              onTap: () {
                context.setLocale(const Locale('generated.nb'.tr(), 'generated.no'.tr()));
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

  const _SettingsSection({
    required this.title,
    required this.children,
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
              color: colorScheme.onSurfaceVariant,
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

  const _SettingsTile({
    this.leading,
    this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return ListTile(
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      leading: leading ?? (icon == null ? null : Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer.withValues(alpha: 0.5),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 20, color: colorScheme.primary),
            )),
      title: Text(
        title,
        style: textTheme.bodyLarge?.copyWith(
          fontWeight: FontWeight.w600,
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
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          trailing ?? const SizedBox.shrink(),
          if (onTap != null) ...[
            const SizedBox(width: 8),
            Icon(
              Icons.chevron_right,
              size: 20,
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
            ),
          ],
        ],
      ),
    );
  }
}
