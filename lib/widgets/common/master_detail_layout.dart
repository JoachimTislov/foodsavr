import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../constants/adaptive_layout.dart';
import 'content_constraint.dart';
import 'empty_state_widget.dart';

/// Shows [master] beside [detail] on expanded windows and [master] alone
/// otherwise (also while [enabled] is false, e.g. for an empty list).
///
/// The caller owns the selection: on a split layout it shows the selected item
/// in [detail] (an empty prompt while it is null); on other layouts it opens
/// the item as a pushed route. See [isSplit].
class MasterDetailLayout extends StatefulWidget {
  final Widget master;
  final Widget? detail;
  final bool enabled;
  final IconData placeholderIcon;

  const MasterDetailLayout({
    super.key,
    required this.master,
    required this.detail,
    this.enabled = true,
    this.placeholderIcon = Icons.touch_app_outlined,
  });

  /// Whether list and detail share the screen at the current window width.
  static bool isSplit(BuildContext context) =>
      WindowSize.of(context).isExpanded;

  @override
  State<MasterDetailLayout> createState() => _MasterDetailLayoutState();
}

class _MasterDetailLayoutState extends State<MasterDetailLayout> {
  // Keeps the master's state when the window crosses the breakpoint.
  final _masterKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    final master = KeyedSubtree(key: _masterKey, child: widget.master);
    if (!widget.enabled || !MasterDetailLayout.isSplit(context)) return master;

    return ContentConstraint(
      maxWidth: AdaptiveLayout.masterDetailMaxWidth,
      child: Row(
        children: [
          SizedBox(width: AdaptiveLayout.masterPaneWidth, child: master),
          const VerticalDivider(width: 1),
          Expanded(
            child:
                widget.detail ??
                EmptyStateWidget(
                  icon: widget.placeholderIcon,
                  title: 'common.selectItem'.tr(),
                ),
          ),
        ],
      ),
    );
  }
}
