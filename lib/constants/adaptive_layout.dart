import 'package:flutter/widgets.dart';

/// Material 3 window size classes, keyed on the window width.
enum WindowSize {
  /// Phones: below [AdaptiveLayout.mediumBreakpoint].
  compact,

  /// Small tablets and foldables.
  medium,

  /// Large tablets, desktop, and web: from [AdaptiveLayout.expandedBreakpoint].
  expanded;

  static WindowSize fromWidth(double width) {
    if (width >= AdaptiveLayout.expandedBreakpoint) return expanded;
    if (width >= AdaptiveLayout.mediumBreakpoint) return medium;
    return compact;
  }

  static WindowSize of(BuildContext context) =>
      fromWidth(MediaQuery.sizeOf(context).width);

  bool get isCompact => this == compact;
  bool get isExpanded => this == expanded;
}

/// Breakpoints and width limits for adaptive layouts.
class AdaptiveLayout {
  const AdaptiveLayout._();

  static const double mediumBreakpoint = 600;
  static const double expandedBreakpoint = 840;

  /// From this window width the navigation rail shows labels beside icons.
  static const double extendedRailBreakpoint = 1200;

  /// Width of the list pane when a list and a detail view share the screen.
  static const double masterPaneWidth = 400;

  /// Upper bound for the combined list and detail panes.
  static const double masterDetailMaxWidth = 1600;

  /// Readable width for single-column page content.
  static const double pageMaxWidth = 960;

  /// Readable width for a detail view.
  static const double detailMaxWidth = 720;

  /// Extra horizontal space on each side of content wider than [maxWidth].
  static double gutterFor(double width, double maxWidth) =>
      width > maxWidth ? (width - maxWidth) / 2 : 0;
}
