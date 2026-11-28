import 'package:flutter/material.dart';

import 'settings_icon.dart';
import 'settings_row_subtitle.dart';
import 'settings_row_title.dart';

/// A settings row that is tappable as a whole.
class SettingsTile extends StatelessWidget {
  final Widget? leading;
  final IconData? icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  const SettingsTile({
    super.key,
    this.leading,
    this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      leading: leading ?? (icon == null ? null : SettingsIcon(icon!)),
      title: SettingsRowTitle(title),
      subtitle: subtitle == null ? null : SettingsRowSubtitle(subtitle!),
      trailing: trailing,
    );
  }
}
