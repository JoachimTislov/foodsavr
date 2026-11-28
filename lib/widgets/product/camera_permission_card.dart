import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../constants/material3_config.dart';
import '../../controllers/pwa_install_controller.dart';
import '../../service_locator.dart';
import '../../services/camera_permission_service.dart';
import '../../utils/camera_setup_guide.dart';

/// Explains why the camera cannot be used and what the user can do about it.
class CameraPermissionCard extends StatelessWidget {
  final CameraAccessStatus status;

  /// Asks for access again, or restarts the camera.
  final VoidCallback onRetry;

  /// Turns the app's camera setting on; offered while it is off.
  final VoidCallback? onEnable;

  /// Continues without the camera.
  final VoidCallback? onFallback;
  final String? fallbackLabel;

  /// The system and browser the setup steps describe; detected when null.
  final PwaPlatformHint? platformHint;

  const CameraPermissionCard({
    super.key,
    required this.status,
    required this.onRetry,
    this.onEnable,
    this.onFallback,
    this.fallbackLabel,
    this.platformHint,
  }) : assert(onFallback == null || fallbackLabel != null);

  PwaPlatformHint get _hint =>
      platformHint ??
      (getIt.isRegistered<PwaInstallController>()
          ? getIt<PwaInstallController>().platformHint
          : PwaPlatformHint.unsupported);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final (icon, title, message) = switch (status) {
      CameraAccessStatus.granted || CameraAccessStatus.prompt => (
        Icons.photo_camera_outlined,
        'camera.prompt.title'.tr(),
        'camera.prompt.message'.tr(),
      ),
      CameraAccessStatus.disabledInSettings => (
        Icons.no_photography_outlined,
        'camera.disabled.title'.tr(),
        'camera.disabled.message'.tr(),
      ),
      CameraAccessStatus.denied => (
        Icons.block,
        'camera.denied.title'.tr(),
        'camera.denied.message'.tr(),
      ),
      CameraAccessStatus.noCamera => (
        Icons.videocam_off_outlined,
        'camera.noCamera.title'.tr(),
        'camera.noCamera.message'.tr(),
      ),
      CameraAccessStatus.insecureContext => (
        Icons.lock_open_outlined,
        'camera.insecureContext.title'.tr(),
        'camera.insecureContext.message'.tr(),
      ),
      CameraAccessStatus.inUse => (
        Icons.error_outline,
        'camera.inUse.title'.tr(),
        'camera.inUse.message'.tr(),
      ),
      CameraAccessStatus.unsupported => (
        Icons.no_photography_outlined,
        'camera.unsupported.title'.tr(),
        'camera.unsupported.message'.tr(),
      ),
    };
    final retryLabel =
        status == CameraAccessStatus.prompt ||
            status == CameraAccessStatus.granted
        ? 'camera.allow'.tr()
        : 'common.tryAgain'.tr();
    final actions = switch (status) {
      CameraAccessStatus.unsupported || CameraAccessStatus.insecureContext => [
        if (onFallback != null)
          FilledButton(onPressed: onFallback, child: Text(fallbackLabel!)),
      ],
      CameraAccessStatus.noCamera => [
        if (onFallback != null) ...[
          OutlinedButton(onPressed: onRetry, child: Text(retryLabel)),
          FilledButton(onPressed: onFallback, child: Text(fallbackLabel!)),
        ] else
          FilledButton(onPressed: onRetry, child: Text(retryLabel)),
      ],
      CameraAccessStatus.disabledInSettings when onEnable != null => [
        if (onFallback != null)
          TextButton(onPressed: onFallback, child: Text(fallbackLabel!)),
        FilledButton(onPressed: onEnable, child: Text('camera.enable'.tr())),
      ],
      _ => [
        if (onFallback != null)
          TextButton(onPressed: onFallback, child: Text(fallbackLabel!)),
        FilledButton(onPressed: onRetry, child: Text(retryLabel)),
      ],
    };

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(Material3Config.spacing16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                ExcludeSemantics(child: Icon(icon, color: colorScheme.primary)),
                const SizedBox(width: Material3Config.spacing16),
                Expanded(
                  child: Text(title, style: theme.textTheme.titleMedium),
                ),
              ],
            ),
            const SizedBox(height: Material3Config.spacing8),
            Text(
              message,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            if (status == CameraAccessStatus.denied) ...[
              const SizedBox(height: Material3Config.spacing12),
              Text(
                'camera.guide.title'.tr(),
                style: theme.textTheme.titleSmall,
              ),
              const SizedBox(height: Material3Config.spacing8),
              for (final (index, step) in cameraSetupSteps(_hint).indexed)
                Padding(
                  padding: const EdgeInsets.only(
                    bottom: Material3Config.spacing4,
                  ),
                  child: Text(
                    '${index + 1}. $step',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
            ],
            if (actions.isNotEmpty) ...[
              const SizedBox(height: Material3Config.spacing16),
              Wrap(
                alignment: WrapAlignment.end,
                spacing: Material3Config.spacing8,
                runSpacing: Material3Config.spacing8,
                children: actions,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
