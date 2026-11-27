import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

/// Shared in-app notification banner that automatically hides when [visible]
/// becomes `false` (fulfilled intent) and always renders an accessible dismiss
/// button.
class DismissibleBanner extends StatelessWidget {
  final bool visible;
  final VoidCallback onDismiss;
  final Widget leading;
  final Widget content;
  final Widget? action;
  final Color backgroundColor;
  final Color? dismissIconColor;
  final ShapeBorder? shape;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final double leadingSpacing;
  final bool useTopSafeArea;
  final bool liveRegion;
  final String? dismissTooltip;

  const DismissibleBanner({
    super.key,
    required this.visible,
    required this.onDismiss,
    required this.leading,
    required this.content,
    required this.backgroundColor,
    this.action,
    this.dismissIconColor,
    this.shape,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    this.margin = EdgeInsets.zero,
    this.leadingSpacing = 12,
    this.useTopSafeArea = false,
    this.liveRegion = false,
    this.dismissTooltip,
  });

  @override
  Widget build(BuildContext context) {
    if (!visible) return const SizedBox.shrink();

    Widget row = Padding(
      padding: padding,
      child: Row(
        children: [
          leading,
          SizedBox(width: leadingSpacing),
          Expanded(child: content),
          if (action != null) ...[const SizedBox(width: 8), action!],
          IconButton(
            icon: Icon(Icons.close, size: 18, color: dismissIconColor),
            tooltip: dismissTooltip ?? 'common.close'.tr(),
            visualDensity: VisualDensity.compact,
            onPressed: onDismiss,
          ),
        ],
      ),
    );

    if (useTopSafeArea) {
      row = SafeArea(bottom: false, child: row);
    }

    Widget banner = Padding(
      padding: margin,
      child: Material(color: backgroundColor, shape: shape, child: row),
    );

    if (liveRegion) {
      banner = Semantics(liveRegion: true, child: banner);
    }

    return banner;
  }
}
