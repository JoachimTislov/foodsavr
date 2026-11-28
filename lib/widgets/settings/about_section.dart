import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../constants/public_routes.dart';
import '../../controllers/pwa_install_controller.dart';
import '../common/pwa_install_banner.dart';
import 'settings_section.dart';
import 'settings_tile.dart';

/// App installation, legal documents and the app version.
class AboutSection extends StatelessWidget {
  final PwaInstallController? pwaInstallController;
  final String? version;

  const AboutSection({
    super.key,
    required this.pwaInstallController,
    required this.version,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: pwaInstallController ?? ChangeNotifier(),
      builder: (context, _) {
        final pwa = pwaInstallController;
        return SettingsSection(
          title: 'settings.about'.tr(),
          children: [
            if (pwa != null && pwa.canInstall)
              SettingsTile(
                icon: Icons.install_mobile_outlined,
                title: 'settings.install_app'.tr(),
                subtitle: 'settings.install_app_subtitle'.tr(),
                onTap: () => PwaInstallSheet.handleInstallTap(context, pwa),
              )
            else if (pwa != null && pwa.isInstalled)
              SettingsTile(
                icon: Icons.check_circle_outline,
                title: 'settings.app_installed'.tr(),
              ),
            SettingsTile(
              icon: Icons.description_outlined,
              title: 'settings.terms_of_service'.tr(),
              onTap: () => context.push(PublicRoutes.terms),
            ),
            SettingsTile(
              icon: Icons.privacy_tip_outlined,
              title: 'settings.privacy_policy'.tr(),
              onTap: () => context.push(PublicRoutes.privacy),
            ),
            SettingsTile(
              icon: Icons.info_outline,
              title: 'settings.app_version'.tr(),
              trailing: version == null ? null : Text(version!),
            ),
          ],
        );
      },
    );
  }
}
