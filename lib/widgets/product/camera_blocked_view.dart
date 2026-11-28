import 'package:flutter/material.dart';

import '../../constants/material3_config.dart';
import '../../services/camera_permission_service.dart';
import 'camera_permission_card.dart';

/// A [CameraPermissionCard] filling a scanner screen that has no camera.
class CameraBlockedView extends StatelessWidget {
  static const _maxWidth = 560.0;

  final CameraAccessStatus status;
  final VoidCallback onRetry;
  final VoidCallback onEnable;
  final VoidCallback onFallback;
  final String fallbackLabel;

  const CameraBlockedView({
    super.key,
    required this.status,
    required this.onRetry,
    required this.onEnable,
    required this.onFallback,
    required this.fallbackLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(Material3Config.spacing24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _maxWidth),
          child: CameraPermissionCard(
            status: status,
            onRetry: onRetry,
            onEnable: onEnable,
            onFallback: onFallback,
            fallbackLabel: fallbackLabel,
          ),
        ),
      ),
    );
  }
}
