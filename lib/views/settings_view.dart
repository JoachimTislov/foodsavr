import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:logger/logger.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:watch_it/watch_it.dart';

import '../constants/preferences_config.dart';
import '../controllers/preferences_controller.dart';
import '../controllers/pwa_install_controller.dart';
import '../features/third_party_integration/widgets/connections_list.dart';
import '../interfaces/i_auth_service.dart';
import '../models/collection_model.dart';
import '../service_locator.dart';
import '../services/collection_service.dart';
import '../utils/collection_types.dart';
import '../utils/theme_notifier.dart';
import '../widgets/common/content_constraint.dart';
import '../widgets/settings/about_section.dart';
import '../widgets/settings/account_section.dart';
import '../widgets/settings/appearance_section.dart';
import '../widgets/settings/camera_access_tile.dart';
import '../widgets/settings/data_export_section.dart';
import '../widgets/settings/settings_section.dart';
import '../widgets/settings/settings_tile.dart';
import '../widgets/settings/social_connections_section.dart';

class SettingsView extends StatefulWidget {
  const SettingsView({super.key});

  @override
  State<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<SettingsView> {
  late final IAuthService _authService;
  late final ThemeNotifier _themeNotifier;
  late final Stream<User?> _authChanges;
  PwaInstallController? _pwaInstallController;
  String? _version;

  @override
  void initState() {
    super.initState();
    _themeNotifier = getIt<ThemeNotifier>();
    _loadVersion();
    _authService = getIt<IAuthService>();
    _authChanges = _authService.authStateChanges;
    if (getIt.isRegistered<PwaInstallController>()) {
      _pwaInstallController = getIt<PwaInstallController>();
    }
  }

  Future<void> _loadVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (mounted) {
        setState(() => _version = '${info.version} (${info.buildNumber})');
      }
    } catch (e) {
      getIt<Logger>().w('Failed to read the app version: $e');
    }
  }

  /// Rebuilds after a sign-in method may have changed; linking does not emit
  /// an auth state event.
  void _refresh() {
    if (mounted) setState(() {});
  }

  Future<void> _openProfile(BuildContext context) async {
    await context.push('/settings/profile');
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    // A language change rebuilds this view and, through it, every section
    // that is not const.
    context.locale;
    return Scaffold(
      appBar: AppBar(title: Text('settings.title'.tr()), centerTitle: true),
      body: SingleChildScrollView(
        child: ContentConstraint(
          maxWidth: SettingsSection.maxContentWidth,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: StreamBuilder<User?>(
              stream: _authChanges,
              initialData: _authService.currentUser,
              builder: (context, snapshot) {
                final user = snapshot.data;
                const gap = SizedBox(height: 24);
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AccountSection(
                      user: user,
                      authService: _authService,
                      onOpenProfile: () => _openProfile(context),
                      onChanged: _refresh,
                    ),
                    gap,
                    AppearanceSection(themeNotifier: _themeNotifier),
                    gap,
                    const _BehaviorSection(),
                    gap,
                    SocialConnectionsSection(
                      authService: _authService,
                      onChanged: _refresh,
                    ),
                    gap,
                    OAuthConnectionsList(),
                    gap,
                    SettingsSection(
                      title: 'settings.permissions'.tr(),
                      children: [CameraAccessTile()],
                    ),
                    gap,
                    DataExportSection(
                      key: ValueKey(_authService.getUserId()),
                      authService: _authService,
                    ),
                    gap,
                    AboutSection(
                      pwaInstallController: _pwaInstallController,
                      version: _version,
                    ),
                  ],
                );
              },
            ),
          ),
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
    // Rebuilds the translated labels when the language changes.
    context.locale;
    final preferences = watchIt<PreferencesController>();
    final defaultInventory = _inventories
        .where((c) => c.id == preferences.defaultInventoryId)
        .firstOrNull;
    final valueStyle = textTheme.bodyMedium?.copyWith(
      color: colorScheme.primary,
      fontWeight: FontWeight.bold,
    );

    return SettingsSection(
      title: 'settings.behavior.title'.tr(),
      children: [
        SettingsTile(
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
        SettingsTile(
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
                tooltip: 'a11y.decreaseDays'.tr(),
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
                tooltip: 'a11y.increaseDays'.tr(),
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
