import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:logger/logger.dart';
import 'package:watch_it/watch_it.dart';

import '../constants/legal_docs.dart';
import '../constants/preferences_config.dart';
import '../controllers/preferences_controller.dart';
import '../controllers/pwa_install_controller.dart';
import '../interfaces/i_auth_service.dart';
import '../models/collection_model.dart';
import '../service_locator.dart';
import '../services/collection_service.dart';
import '../utils/collection_types.dart';
import '../utils/theme_notifier.dart';
import '../features/third_party_integration/widgets/connections_list.dart';
import '../widgets/common/pwa_install_banner.dart';

class SettingsView extends StatefulWidget {
  const SettingsView({super.key});

  @override
  State<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<SettingsView> {
  late final IAuthService _authService;
  PwaInstallController? _pwaInstallController;

  @override
  void initState() {
    super.initState();
    _authService = getIt<IAuthService>();
    if (getIt.isRegistered<PwaInstallController>()) {
      _pwaInstallController = getIt<PwaInstallController>();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    return Scaffold(
      appBar: AppBar(title: Text('settings.title'.tr()), centerTitle: true),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // User Profile Section
            StreamBuilder<User?>(
              stream: _authService.authStateChanges,
              initialData: _authService.currentUser,
              builder: (context, snapshot) {
                final user = snapshot.data;
                final isAnonymous = user?.isAnonymous ?? false;
                final displayName = isAnonymous
                    ? 'settings.guest_user'.tr()
                    : (user?.displayName ??
                          user?.email?.split('@').first ??
                          '');
                final email = isAnonymous ? null : (user?.email);

                return _SettingsSection(
                  title: 'settings.account'.tr(),
                  children: [
                    _SettingsTile(
                      leading: CircleAvatar(
                        radius: 20,
                        backgroundColor: colorScheme.primaryContainer,
                        backgroundImage: !isAnonymous && user?.photoURL != null
                            ? NetworkImage(user!.photoURL!)
                            : null,
                        child: isAnonymous || user?.photoURL == null
                            ? Icon(
                                Icons.person_outline,
                                size: 20,
                                color: colorScheme.onPrimaryContainer,
                              )
                            : null,
                      ),
                      title: displayName,
                      subtitle: email,
                      onTap: () => context.push('/settings/profile'),
                    ),
                  ],
                );
              },
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
            const _BehaviorSection(),
            const SizedBox(height: 24),
            OAuthConnectionsList(),
            const SizedBox(height: 24),

            // Legal & Info Section
            ListenableBuilder(
              listenable: _pwaInstallController ?? ChangeNotifier(),
              builder: (context, _) {
                final pwa = _pwaInstallController;
                return _SettingsSection(
                  title: 'settings.about'.tr(),
                  children: [
                    if (pwa != null && pwa.canInstall)
                      _SettingsTile(
                        icon: Icons.install_mobile_outlined,
                        title: 'settings.install_app'.tr(),
                        subtitle: 'settings.install_app_subtitle'.tr(),
                        onTap: () =>
                            PwaInstallSheet.handleInstallTap(context, pwa),
                      )
                    else if (pwa != null && pwa.isInstalled)
                      _SettingsTile(
                        icon: Icons.check_circle_outline,
                        title: 'settings.app_installed'.tr(),
                        onTap: null,
                      ),
                    _SettingsTile(
                      icon: Icons.description_outlined,
                      title: 'settings.terms_of_service'.tr(),
                      onTap: () => _showLegalDoc(
                        context,
                        title: 'common.terms_of_service'.tr(),
                        loadContent: LegalDocs.termsOfService,
                      ),
                    ),
                    _SettingsTile(
                      icon: Icons.privacy_tip_outlined,
                      title: 'settings.privacy_policy'.tr(),
                      onTap: () => _showLegalDoc(
                        context,
                        title: 'common.privacy_notice'.tr(),
                        loadContent: LegalDocs.privacyNotice,
                      ),
                    ),
                    _SettingsTile(
                      icon: Icons.info_outline,
                      title: 'settings.app_version'.tr(),
                      trailing: Text('generated.100_42'.tr()),
                      onTap: null,
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showLegalDoc(
    BuildContext context, {
    required String title,
    required Future<String> Function() loadContent,
  }) async {
    final content = await loadContent();
    if (!context.mounted) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(child: Text(content)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('common.close'.tr()),
          ),
        ],
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
                context.setLocale(const Locale('en'));
                Navigator.pop(context);
              },
            ),
            ListTile(
              title: Text('settings.languages.nb'.tr()),
              trailing: context.locale.languageCode == 'nb'
                  ? const Icon(Icons.check, color: Colors.blue)
                  : null,
              onTap: () {
                context.setLocale(const Locale('nb'));
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// Account-synced behavior preferences (see [PreferencesController]).
class _BehaviorSection extends WatchingStatefulWidget {
  const _BehaviorSection();

  @override
  State<_BehaviorSection> createState() => _BehaviorSectionState();
}

class _BehaviorSectionState extends State<_BehaviorSection> {
  List<Collection> _inventories = const [];

  @override
  void initState() {
    super.initState();
    _loadInventories();
  }

  Future<void> _loadInventories() async {
    try {
      final inventories = await getIt<CollectionService>()
          .getCollectionsForUser(
            getIt<IAuthService>().getUserId(),
            type: CollectionType.inventory,
          );
      if (mounted) setState(() => _inventories = inventories);
    } catch (e) {
      // The default inventory then shows as the first-inventory fallback.
      getIt<Logger>().w('Failed to load inventories for settings: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final preferences = watchIt<PreferencesController>();
    final defaultInventory = _inventories
        .where((c) => c.id == preferences.defaultInventoryId)
        .firstOrNull;
    final valueStyle = textTheme.bodyMedium?.copyWith(
      color: colorScheme.primary,
      fontWeight: FontWeight.bold,
    );

    return _SettingsSection(
      title: 'settings.behavior.title'.tr(),
      children: [
        _SettingsTile(
          icon: Icons.hourglass_bottom_outlined,
          title: 'settings.behavior.expiringSoonWindow'.tr(),
          subtitle: 'settings.behavior.expiringSoonWindowHelp'.tr(),
          trailing: Text(
            'product.status_days'.tr(
              namedArgs: {'days': '${preferences.expiringSoonDays}'},
            ),
            style: valueStyle,
          ),
          onTap: () => _showExpiringSoonDialog(context, preferences),
        ),
        _SettingsTile(
          icon: Icons.inventory_2_outlined,
          title: 'settings.behavior.defaultInventory'.tr(),
          subtitle: 'settings.behavior.defaultInventoryHelp'.tr(),
          trailing: Text(
            defaultInventory?.name ?? 'settings.behavior.firstInventory'.tr(),
            style: valueStyle,
          ),
          onTap: () => _showInventorySelector(context, preferences),
        ),
      ],
    );
  }

  /// Reports a preference that could not be synced; it stays on this device.
  void _sync(Future<void> update) {
    final messenger = ScaffoldMessenger.of(context);
    update.catchError((Object _) {
      messenger.showSnackBar(
        SnackBar(content: Text('settings.behavior.syncError'.tr())),
      );
    });
  }

  Future<void> _showExpiringSoonDialog(
    BuildContext context,
    PreferencesController preferences,
  ) {
    var days = preferences.expiringSoonDays;
    return showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('settings.behavior.expiringSoonWindow'.tr()),
          content: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.remove),
                onPressed: days > PreferencesConfig.minExpiringSoonDays
                    ? () => setDialogState(() => days--)
                    : null,
              ),
              Text(
                'product.status_days'.tr(namedArgs: {'days': '$days'}),
                style: Theme.of(context).textTheme.titleLarge,
              ),
              IconButton(
                icon: const Icon(Icons.add),
                onPressed: days < PreferencesConfig.maxExpiringSoonDays
                    ? () => setDialogState(() => days++)
                    : null,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('common.cancel'.tr()),
            ),
            FilledButton(
              onPressed: () {
                _sync(preferences.setExpiringSoonDays(days));
                Navigator.of(context).pop();
              },
              child: Text('common.save'.tr()),
            ),
          ],
        ),
      ),
    );
  }

  void _showInventorySelector(
    BuildContext context,
    PreferencesController preferences,
  ) {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: Text('settings.behavior.firstInventory'.tr()),
                trailing: preferences.defaultInventoryId == null
                    ? const Icon(Icons.check)
                    : null,
                onTap: () {
                  _sync(preferences.setDefaultInventoryId(null));
                  Navigator.pop(context);
                },
              ),
              if (_inventories.isEmpty)
                ListTile(
                  enabled: false,
                  title: Text('settings.behavior.noInventories'.tr()),
                ),
              for (final inventory in _inventories)
                ListTile(
                  title: Text(inventory.name),
                  trailing: preferences.defaultInventoryId == inventory.id
                      ? const Icon(Icons.check)
                      : null,
                  onTap: () {
                    _sync(preferences.setDefaultInventoryId(inventory.id));
                    Navigator.pop(context);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingsSection extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _SettingsSection({required this.title, required this.children});

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
        Material(
          color: colorScheme.surfaceContainer,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(
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
      leading:
          leading ??
          (icon == null
              ? null
              : Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer.withValues(alpha: 0.5),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, size: 20, color: colorScheme.primary),
                )),
      title: Text(
        title,
        style: textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
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
