import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../controllers/pwa_install_controller.dart';
import '../../service_locator.dart';
import 'dismissible_banner.dart';

/// Material 3 banner card that prompts web users to install LettMat as a PWA.
///
/// Automatically hides when the app is not running in a web browser, is already
/// installed in standalone mode (fulfilled intent), or when the user dismisses
/// the banner. Without a native prompt, the install button opens the steps for
/// the user's browser and operating system.
class PwaInstallBanner extends StatelessWidget {
  final PwaInstallController? controller;
  final EdgeInsetsGeometry? margin;

  const PwaInstallBanner({super.key, this.controller, this.margin});

  PwaInstallController? _resolveController() {
    if (controller != null) return controller;
    if (getIt.isRegistered<PwaInstallController>()) {
      return getIt<PwaInstallController>();
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final resolved = _resolveController();
    if (resolved == null) return const SizedBox.shrink();

    return ListenableBuilder(
      listenable: resolved,
      builder: (context, _) {
        final theme = Theme.of(context);
        final colorScheme = theme.colorScheme;
        final textTheme = theme.textTheme;

        return DismissibleBanner(
          visible: resolved.shouldShowBanner,
          onDismiss: resolved.dismissBanner,
          margin: margin ?? EdgeInsets.zero,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          backgroundColor: colorScheme.primaryContainer.withValues(alpha: 0.45),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(
              color: colorScheme.primary.withValues(alpha: 0.25),
            ),
          ),
          leading: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: colorScheme.primary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              Icons.install_mobile_outlined,
              color: colorScheme.primary,
              size: 24,
            ),
          ),
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'pwa.banner.title'.tr(),
                style: textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'pwa.banner.subtitle'.tr(),
                style: textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          action: FilledButton.tonal(
            onPressed: resolved.isPrompting
                ? null
                : () => PwaInstallSheet.handleInstallTap(context, resolved),
            child: Text('pwa.banner.install'.tr()),
          ),
        );
      },
    );
  }
}

/// Modal bottom sheet that guides users through manual PWA installation when
/// the browser does not expose a native `beforeinstallprompt` dialog (e.g.,
/// iOS Safari, macOS Safari, or Firefox).
class PwaInstallSheet extends StatelessWidget {
  final PwaPlatformHint platformHint;

  const PwaInstallSheet({super.key, required this.platformHint});

  /// Attempts native one-tap installation first; if unavailable in the current
  /// browser, displays the platform-tailored installation guide bottom sheet.
  static Future<void> handleInstallTap(
    BuildContext context,
    PwaInstallController controller,
  ) async {
    final result = await controller.requestInstall();
    if (!context.mounted) return;

    if (result == PwaPromptResult.accepted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('pwa.installed_snackbar'.tr())));
    } else if (result == PwaPromptResult.unavailable) {
      await show(context, platformHint: controller.platformHint);
    }
  }

  static Future<void> show(
    BuildContext context, {
    required PwaPlatformHint platformHint,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => PwaInstallSheet(platformHint: platformHint),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    final steps = switch (platformHint) {
      PwaPlatformHint.ios => [
        _InstallStep(
          number: '1',
          icon: Icons.ios_share_outlined,
          text: 'pwa.guide.ios_step1'.tr(),
        ),
        _InstallStep(
          number: '2',
          icon: Icons.add_box_outlined,
          text: 'pwa.guide.ios_step2'.tr(),
        ),
      ],
      PwaPlatformHint.macosSafari => [
        _InstallStep(
          number: '1',
          icon: Icons.ios_share_outlined,
          text: 'pwa.guide.safari_step1'.tr(),
        ),
        _InstallStep(
          number: '2',
          icon: Icons.web_asset_outlined,
          text: 'pwa.guide.safari_step2'.tr(),
        ),
      ],
      PwaPlatformHint.android => [
        _InstallStep(
          number: '1',
          icon: Icons.more_vert,
          text: 'pwa.guide.android_step1'.tr(),
        ),
        _InstallStep(
          number: '2',
          icon: Icons.add_to_home_screen_outlined,
          text: 'pwa.guide.android_step2'.tr(),
        ),
      ],
      PwaPlatformHint.firefoxAndroid => [
        _InstallStep(
          number: '1',
          icon: Icons.more_vert,
          text: 'pwa.guide.firefox_android_step1'.tr(),
        ),
        _InstallStep(
          number: '2',
          icon: Icons.add_to_home_screen_outlined,
          text: 'pwa.guide.firefox_android_step2'.tr(),
        ),
      ],
      PwaPlatformHint.firefoxDesktop => [
        _InstallStep(
          number: '1',
          icon: Icons.menu,
          text: 'pwa.guide.firefox_desktop_step1'.tr(),
        ),
        _InstallStep(
          number: '2',
          icon: Icons.install_desktop_outlined,
          text: 'pwa.guide.firefox_desktop_step2'.tr(),
        ),
      ],
      _ => [
        _InstallStep(
          number: '1',
          icon: Icons.install_desktop_outlined,
          text: 'pwa.guide.standard_step1'.tr(),
        ),
        _InstallStep(
          number: '2',
          icon: Icons.add_to_home_screen_outlined,
          text: 'pwa.guide.standard_step2'.tr(),
        ),
      ],
    };

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    Icons.install_mobile_outlined,
                    color: colorScheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'pwa.guide.title'.tr(),
                    style: textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'pwa.guide.subtitle'.tr(),
              style: textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
            for (final step in steps) ...[
              _InstallStepTile(step: step),
              const SizedBox(height: 12),
            ],
          ],
        ),
      ),
    );
  }
}

class _InstallStep {
  final String number;
  final IconData icon;
  final String text;

  const _InstallStep({
    required this.number,
    required this.icon,
    required this.text,
  });
}

class _InstallStepTile extends StatelessWidget {
  final _InstallStep step;

  const _InstallStepTile({required this.step});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: colorScheme.primary,
            foregroundColor: colorScheme.onPrimary,
            child: Text(
              step.number,
              style: textTheme.labelMedium?.copyWith(
                color: colorScheme.onPrimary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Icon(step.icon, color: colorScheme.primary, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              step.text,
              style: textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
