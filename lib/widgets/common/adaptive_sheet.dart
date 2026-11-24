import 'package:flutter/material.dart';

import '../../constants/adaptive_layout.dart';
import '../../constants/material3_config.dart';

/// Presents one body widget as a modal bottom sheet on Compact windows and as
/// a centered dialog on Medium and Expanded windows.
///
/// The body is built once per presentation; pop with a value to return it.
/// The sheet supplies the outer padding, radius and keyboard inset, so the body
/// lays out its own content only.
class AdaptiveSheet {
  const AdaptiveSheet._();

  /// Dialog width on Medium and Expanded windows.
  static const double dialogWidth = 560;

  /// Padding around the body in both presentations.
  static const double padding = 24;

  static const double _radius = Material3Config.radiusExtraLarge;

  static Future<T?> show<T>(
    BuildContext context, {
    required WidgetBuilder builder,
    bool barrierDismissible = true,
  }) {
    if (WindowSize.of(context).isCompact) {
      return showModalBottomSheet<T>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        showDragHandle: true,
        isDismissible: barrierDismissible,
        enableDrag: barrierDismissible,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(_radius)),
        ),
        builder: (context) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(padding, 0, padding, padding),
              child: builder(context),
            ),
          ),
        ),
      );
    }
    return showDialog<T>(
      context: context,
      barrierDismissible: barrierDismissible,
      barrierColor: Colors.black.withValues(alpha: 0.4),
      builder: (context) => Dialog(
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(_radius)),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints.tightFor(width: dialogWidth),
          child: Padding(
            padding: const EdgeInsets.all(padding),
            child: builder(context),
          ),
        ),
      ),
    );
  }
}
