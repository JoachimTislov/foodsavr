import 'package:flutter/material.dart';

import 'settings_icon.dart';
import 'settings_row_subtitle.dart';
import 'settings_row_title.dart';

/// A settings row whose [action] is its own control. The row states context or
/// status; the control states the action. The control moves below the text when
/// the row is narrower than [stackBelow], so the text is never squeezed.
class SettingsActionRow extends StatelessWidget {
  static const double _leadingSize = 36;
  static const double _gap = 16;

  final IconData? icon;
  final Widget? leading;
  final String title;
  final String? subtitle;
  final Widget? action;
  final bool isDestructive;
  final double stackBelow;

  const SettingsActionRow({
    super.key,
    this.icon,
    this.leading,
    required this.title,
    this.subtitle,
    this.action,
    this.isDestructive = false,
    this.stackBelow = 440,
  });

  @override
  Widget build(BuildContext context) {
    final label = Row(
      children: [
        SizedBox(
          width: _leadingSize,
          child: Center(
            child:
                leading ??
                (icon == null
                    ? null
                    : SettingsIcon(icon!, isDestructive: isDestructive)),
          ),
        ),
        const SizedBox(width: _gap),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SettingsRowTitle(title, isDestructive: isDestructive),
              if (subtitle != null) SettingsRowSubtitle(subtitle!),
            ],
          ),
        ),
      ],
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: action == null
          ? label
          : LayoutBuilder(
              builder: (context, constraints) =>
                  constraints.maxWidth < stackBelow
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        label,
                        const SizedBox(height: 8),
                        Padding(
                          padding: const EdgeInsets.only(
                            left: _leadingSize + _gap,
                          ),
                          child: action,
                        ),
                      ],
                    )
                  : Row(
                      children: [
                        Expanded(child: label),
                        const SizedBox(width: _gap),
                        action!,
                      ],
                    ),
            ),
    );
  }
}
