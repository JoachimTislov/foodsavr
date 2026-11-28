import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:logger/logger.dart';

import '../../service_locator.dart';
import '../../services/camera_preference_service.dart';
import 'settings_icon.dart';
import 'settings_row_subtitle.dart';
import 'settings_row_title.dart';

/// The camera preference with its current status and what to do next.
class CameraAccessTile extends StatefulWidget {
  final CameraPreferenceService? service;

  const CameraAccessTile({super.key, this.service});

  @override
  State<CameraAccessTile> createState() => _CameraAccessTileState();
}

class _CameraAccessTileState extends State<CameraAccessTile> {
  late final CameraPreferenceService _service =
      widget.service ??
      (getIt.isRegistered<CameraPreferenceService>()
          ? getIt<CameraPreferenceService>()
          : CameraPreferenceService());

  /// Null until the stored preference is read.
  bool? _enabled;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    var enabled = true;
    try {
      enabled = await _service.isEnabled();
    } catch (e) {
      getIt<Logger>().w('Failed to read the camera preference: $e');
    }
    if (mounted) setState(() => _enabled = enabled);
  }

  Future<void> _setEnabled(bool enabled) async {
    final previous = _enabled;
    setState(() => _enabled = enabled);
    try {
      await _service.setEnabled(enabled);
    } catch (e) {
      getIt<Logger>().w('Failed to save the camera preference: $e');
      if (!mounted) return;
      setState(() => _enabled = previous);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('settings.camera.saveError'.tr())));
    }
  }

  @override
  Widget build(BuildContext context) {
    final enabled = _enabled ?? true;

    return SwitchListTile(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      secondary: SettingsIcon(
        enabled ? Icons.photo_camera_outlined : Icons.no_photography_outlined,
      ),
      title: SettingsRowTitle('settings.camera.title'.tr()),
      subtitle: SettingsRowSubtitle(
        enabled
            ? 'settings.camera.enabledHint'.tr()
            : 'settings.camera.disabledHint'.tr(),
      ),
      value: enabled,
      onChanged: _enabled == null ? null : _setEnabled,
    );
  }
}
