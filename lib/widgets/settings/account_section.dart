import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../constants/public_routes.dart';
import '../../interfaces/i_auth_service.dart';
import 'password_action_tile.dart';
import 'settings_action_row.dart';
import 'settings_section.dart';
import 'settings_tile.dart';

/// The signed-in account: profile, password and account removal.
class AccountSection extends StatelessWidget {
  final User? user;
  final IAuthService authService;
  final VoidCallback onOpenProfile;
  final VoidCallback onChanged;

  const AccountSection({
    super.key,
    required this.user,
    required this.authService,
    required this.onOpenProfile,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isAnonymous = user?.isAnonymous ?? false;
    final rawName = user?.displayName?.trim();
    final rawEmail = user?.email?.split('@').first.trim();
    final displayName = isAnonymous
        ? 'settings.guest_user'.tr()
        : ((rawName != null && rawName.isNotEmpty)
              ? rawName
              : (rawEmail != null && rawEmail.isNotEmpty)
              ? rawEmail
              : 'profile.title'.tr());
    final photoUrl = isAnonymous ? null : user?.photoURL;

    return SettingsSection(
      title: 'settings.account'.tr(),
      children: [
        SettingsTile(
          leading: CircleAvatar(
            radius: 20,
            backgroundColor: colorScheme.primaryContainer,
            backgroundImage: photoUrl == null ? null : NetworkImage(photoUrl),
            child: photoUrl == null
                ? Icon(
                    Icons.person_outline,
                    size: 20,
                    color: colorScheme.onPrimaryContainer,
                  )
                : null,
          ),
          title: displayName,
          subtitle: isAnonymous ? null : user?.email,
          trailing: const Icon(Icons.chevron_right),
          onTap: onOpenProfile,
        ),
        if (PasswordActionTile.appliesTo(user))
          PasswordActionTile(authService: authService, onChanged: onChanged),
        SettingsActionRow(
          icon: Icons.delete_outline,
          title: 'settings.accountRemoval.title'.tr(),
          subtitle: 'settings.accountRemoval.description'.tr(),
          isDestructive: true,
          action: OutlinedButton(
            style: OutlinedButton.styleFrom(
              foregroundColor: colorScheme.error,
              side: BorderSide(color: colorScheme.error),
            ),
            onPressed: () => context.push(PublicRoutes.deleteAccount),
            child: Text('profile.delete_account'.tr()),
          ),
        ),
      ],
    );
  }
}
