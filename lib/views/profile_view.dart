import 'package:easy_localization/easy_localization.dart';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:watch_it/watch_it.dart'; // Import watch_it
import '../controllers/c_profile.dart'; // Import ProfileController
import '../interfaces/i_auth_service.dart';
import '../service_locator.dart';

class ProfileView extends WatchingWidget {
  const ProfileView({super.key});

  @override
  Widget build(BuildContext context) {
    // Watch the ProfileController
    final profileController = watchIt<ProfileController>();
    final authService = getIt<IAuthService>();

    // Watch auth state changes using watchStream
    final userSnapshot = watchStream(
      (IAuthService s) => s.authStateChanges,
      initialValue: authService.currentUser,
      target: authService,
    );
    final user = userSnapshot.data;
    final isAnonymous = user?.isAnonymous ?? false;
    final displayName = isAnonymous
        ? 'settings.guest_user'.tr()
        : (user?.displayName ?? user?.email?.split('@').first ?? '');
    final email = isAnonymous ? null : user?.email;
    final photoUrl = isAnonymous ? null : user?.photoURL;

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
              context.go('/dashboard');
            }
          },
        ),
        title: Text(
          'profile.title'.tr(),
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: _ProfileHeader(
              name: displayName,
              email: email,
              avatarUrl: photoUrl,
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.all(24),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                const SizedBox(height: 32),
                Text(
                  'profile.account_settings'.tr(),
                  style: textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
                _SettingsGroup(
                  items: [
                    if (user?.isAnonymous ?? false)
                      _SettingsItem(
                        icon: Icons.person_add_alt_1_outlined,
                        label: 'profile.create_account'.tr(),
                        onTap: () => context.go('/auth?mode=signup'),
                      ),
                    _SettingsItem(
                      icon: Icons.lock_reset,
                      label: 'profile.forgot_password'.tr(),
                    ),
                    _SettingsItem(
                      icon: Icons.mail_outline,
                      label: 'profile.change_email'.tr(),
                    ),
                    _SettingsItem(
                      icon: Icons.security,
                      label: 'profile.two_factor_auth'.tr(),
                    ),
                    _SettingsItem(
                      icon: Icons.logout,
                      label: 'profile.log_out'.tr(),
                      isDestructive: true,
                      onTap: () => profileController.signOut(),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                Text(
                  'profile.danger_zone'.tr(),
                  style: textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                    color: Colors.red,
                  ),
                ),
                const SizedBox(height: 16),
                _SettingsGroup(
                  items: [
                    _SettingsItem(
                      icon: Icons.delete_outline,
                      label: 'profile.delete_account'.tr(),
                      isDestructive: true,
                      onTap: () => _showDeleteAccountConfirmation(context, profileController),
                    ),
                  ],
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  void _showDeleteAccountConfirmation(BuildContext context, ProfileController controller) {
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
              'profile.delete_account'.tr(),
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(
              'profile.delete_account_description'.tr(),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                await controller.deleteAccount(); // Call controller method
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
}

class _ProfileHeader extends StatelessWidget {
  final String name;
  final String? _email;
  final String? avatarUrl;

  const _ProfileHeader({required this.name, email, this.avatarUrl})
    : _email = email;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.only(left: 24, top: 32, right: 24, bottom: 32),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainer,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(32)),
      ),
      child: Column(
        children: [
          Stack(
            children: [
              CircleAvatar(
                radius: 56,
                backgroundColor: colorScheme.outlineVariant,
                backgroundImage: avatarUrl != null
                    ? NetworkImage(avatarUrl!) as ImageProvider
                    : null,
                child: avatarUrl == null
                    ? Icon(
                        Icons.person,
                        size: 56,
                        color: colorScheme.onSurfaceVariant,
                      )
                    : null,
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: colorScheme.primary,
                    shape: BoxShape.circle,
                    border: Border.all(color: colorScheme.surface, width: 2),
                  ),
                  child: Icon(
                    Icons.edit,
                    size: 18,
                    color: colorScheme.onPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            name,
            style: textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          if (_email != null)
            Text(
              _email,
              style: textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
        ],
      ),
    );
  }
}

class _SettingsGroup extends StatelessWidget {
  final List<_SettingsItem> items;

  const _SettingsGroup({required this.items});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.1),
        ),
      ),
      child: Column(
        children: [
          for (int i = 0; i < items.length; i++) ...[
            if (i > 0)
              Divider(
                height: 1,
                indent: 64,
                endIndent: 16,
                color: colorScheme.outlineVariant.withValues(alpha: 0.1),
              ),
            items[i],
          ],
        ],
      ),
    );
  }
}

class _SettingsItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool isDestructive;

  const _SettingsItem({
    required this.icon,
    required this.label,
    this.onTap,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final color = isDestructive ? Colors.red : colorScheme.onSurface;

    return ListTile(
      onTap: onTap,
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isDestructive
              ? Colors.red.withValues(alpha: 0.1)
              : colorScheme.surfaceContainer,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 20, color: color),
      ),
      title: Text(
        label,
        style: textTheme.bodyLarge?.copyWith(
          color: color,
          fontWeight: FontWeight.w500,
        ),
      ),
      trailing: null,
    );
  }
}
