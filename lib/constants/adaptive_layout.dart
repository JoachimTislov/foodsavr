import 'package:flutter/widgets.dart';

import 'material3_config.dart';

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

/// Unified responsive spacing, padding, border radius, and max-width tokens
/// for a given [WindowSize].
class AdaptiveLayoutTokens {
  final WindowSize windowSize;
  final double cardRadius;
  final double controlRadius;
  final double chipRadius;
  final EdgeInsets pagePadding;
  final EdgeInsets cardPadding;
  final double sectionSpacing;
  final double itemSpacing;
  final double maxContentWidth;
  final double buttonHorizontalPadding;
  final double buttonVerticalPadding;

  const AdaptiveLayoutTokens({
    required this.windowSize,
    required this.cardRadius,
    required this.controlRadius,
    required this.chipRadius,
    required this.pagePadding,
    required this.cardPadding,
    required this.sectionSpacing,
    required this.itemSpacing,
    required this.maxContentWidth,
    required this.buttonHorizontalPadding,
    required this.buttonVerticalPadding,
  });

  static const compact = AdaptiveLayoutTokens(
    windowSize: WindowSize.compact,
    cardRadius: Material3Config.radiusLarge,
    controlRadius: Material3Config.radiusMedium,
    chipRadius: Material3Config.radiusSmall,
    pagePadding: EdgeInsets.symmetric(
      horizontal: Material3Config.spacing16,
      vertical: Material3Config.spacing12,
    ),
    cardPadding: EdgeInsets.all(Material3Config.spacing16),
    sectionSpacing: Material3Config.spacing16,
    itemSpacing: Material3Config.spacing8,
    maxContentWidth: double.infinity,
    buttonHorizontalPadding: Material3Config.spacing24,
    buttonVerticalPadding: Material3Config.spacing16,
  );

  static const medium = AdaptiveLayoutTokens(
    windowSize: WindowSize.medium,
    cardRadius: Material3Config.radiusMedium,
    controlRadius: Material3Config.radiusDesktopLarge,
    chipRadius: Material3Config.radiusSmall,
    pagePadding: EdgeInsets.symmetric(
      horizontal: Material3Config.spacing24,
      vertical: Material3Config.spacing16,
    ),
    cardPadding: EdgeInsets.all(Material3Config.spacing16),
    sectionSpacing: Material3Config.spacing20,
    itemSpacing: Material3Config.spacing12,
    maxContentWidth: 760,
    buttonHorizontalPadding: Material3Config.spacing20,
    buttonVerticalPadding: Material3Config.spacing12,
  );

  static const expanded = AdaptiveLayoutTokens(
    windowSize: WindowSize.expanded,
    cardRadius: Material3Config.radiusDesktopLarge,
    controlRadius: Material3Config.radiusDesktopMedium,
    chipRadius: Material3Config.radiusDesktopSmall,
    pagePadding: EdgeInsets.symmetric(
      horizontal: Material3Config.spacing32,
      vertical: Material3Config.spacing20,
    ),
    cardPadding: EdgeInsets.all(Material3Config.spacing20),
    sectionSpacing: Material3Config.spacing24,
    itemSpacing: Material3Config.spacing12,
    maxContentWidth: AdaptiveLayout.pageMaxWidth,
    buttonHorizontalPadding: Material3Config.spacing20,
    buttonVerticalPadding: Material3Config.spacing12,
  );
}

/// Breakpoints, width limits, and responsive tokens for adaptive layouts.
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

  /// Readable width for centered empty-state blocks and their action rows.
  static const double emptyStateMaxWidth = 480;

  /// Extra horizontal space on each side of content wider than [maxWidth].
  static double gutterFor(double width, double maxWidth) =>
      width > maxWidth ? (width - maxWidth) / 2 : 0;

  static bool isDesktop(BuildContext context) =>
      WindowSize.of(context).isExpanded;

  static AdaptiveLayoutTokens tokensFor(WindowSize size) => switch (size) {
    WindowSize.compact => AdaptiveLayoutTokens.compact,
    WindowSize.medium => AdaptiveLayoutTokens.medium,
    WindowSize.expanded => AdaptiveLayoutTokens.expanded,
  };

  static AdaptiveLayoutTokens tokensOf(BuildContext context) =>
      tokensFor(WindowSize.of(context));
}
