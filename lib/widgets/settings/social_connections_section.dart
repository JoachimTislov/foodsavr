import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:logger/logger.dart';

import '../../interfaces/i_auth_service.dart';
import '../../service_locator.dart';
import '../../utils/auth_error_handler.dart';
import 'settings_action_row.dart';
import 'settings_section.dart';
import 'social_provider_tile.dart';

/// Shows which social sign-in providers the account has, and links the rest.
class SocialConnectionsSection extends StatefulWidget {
  final IAuthService? authService;

  /// Called after a provider was linked.
  final VoidCallback? onChanged;

  const SocialConnectionsSection({super.key, this.authService, this.onChanged});

  @override
  State<SocialConnectionsSection> createState() =>
      _SocialConnectionsSectionState();
}

class _SocialConnectionsSectionState extends State<SocialConnectionsSection> {
  late final IAuthService _authService =
      widget.authService ?? getIt<IAuthService>();
  SignInProvider? _linking;
  int _attemptId = 0;

  void _cancelLink() {
    if (_linking == null) return;
    _attemptId++;
    setState(() => _linking = null);
  }

  Future<void> _link(
    SignInProvider provider,
    String name,
    Future<void> Function() link,
  ) async {
    if (_linking != null) return;
    final attemptId = ++_attemptId;
    setState(() => _linking = provider);
    String? message;
    try {
      await link();
      if (attemptId != _attemptId) return;
      message = 'settings.connections.linkSuccess'.tr(
        namedArgs: {'provider': name},
      );
      widget.onChanged?.call();
    } catch (error) {
      if (attemptId != _attemptId) return;
      final code = error is FirebaseAuthException
          ? error.code
          : error.runtimeType.toString();
      message = switch (code) {
        // The row shows it as connected after the rebuild below.
        'provider-already-linked' => null,
        'credential-already-in-use' || 'email-already-in-use' =>
          'settings.connections.alreadyInUse'.tr(namedArgs: {'provider': name}),
        _ => AuthErrorHandler.getProviderErrorMessage(
          provider,
          error,
          (key) => key.tr(),
        ),
      };
      // SDK error messages can contain OAuth tokens, so only log the code.
      if (message != null) {
        getIt<Logger>().w('Could not link ${provider.name}: $code');
      }
    } finally {
      if (mounted && attemptId == _attemptId) {
        setState(() => _linking = null);
      }
    }
    if (!mounted || attemptId != _attemptId) return;
    if (message != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _authService.currentUser;
    final account = user == null || user.isAnonymous ? null : user;
    final providers = [
      (
        provider: SignInProvider.google,
        id: GoogleAuthProvider.PROVIDER_ID,
        name: 'Google',
        logo: 'assets/logos/google.svg',
        link: _authService.linkGoogleProvider,
      ),
      (
        provider: SignInProvider.facebook,
        id: FacebookAuthProvider.PROVIDER_ID,
        name: 'Facebook',
        logo: 'assets/logos/facebook.svg',
        link: _authService.linkFacebookProvider,
      ),
    ];

    return SettingsSection(
      title: 'settings.connections.title'.tr(),
      children: [
        for (final entry in providers)
          SocialProviderTile(
            name: entry.name,
            logoPath: entry.logo,
            linked: account?.providerData
                .where((info) => info.providerId == entry.id)
                .firstOrNull,
            busy: _linking == entry.provider,
            canConnect: account != null,
            onConnect: _linking != null
                ? null
                : () => _link(entry.provider, entry.name, entry.link),
            onCancel: _linking == entry.provider ? _cancelLink : null,
          ),
        if (account == null)
          SettingsActionRow(
            icon: Icons.person_add_alt_1_outlined,
            title: 'settings.connections.guestTitle'.tr(),
            subtitle: 'settings.connections.guestHint'.tr(),
            action: TextButton(
              onPressed: () => context.go('/auth?mode=signup'),
              child: Text('profile.create_account'.tr()),
            ),
          ),
      ],
    );
  }
}
