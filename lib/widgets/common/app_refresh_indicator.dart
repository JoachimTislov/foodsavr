import 'package:flutter/material.dart';

/// A native wrapper for pull-to-refresh functionality.
/// Ensures consistent refresh indicator behavior and styling across the app.
class AppRefreshIndicator extends StatelessWidget {
  final Future<void> Function() onRefresh;
  final Widget child;

  /// Whether the [child] provides its own scrolling (e.g., [ListView], [SingleChildScrollView]).
  /// If false, the [child] will be wrapped in a scrollable view that fills the viewport
  /// so that pull-to-refresh still works (ideal for Empty or Error states).
  final bool isScrollable;

  const AppRefreshIndicator({
    super.key,
    required this.onRefresh,
    required this.child,
    this.isScrollable = true,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (isScrollable) {
      return RefreshIndicator(
        onRefresh: onRefresh,
        color: colorScheme.primary,
        backgroundColor: colorScheme.surfaceContainerHigh,
        child: child,
      );
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      color: colorScheme.primary,
      backgroundColor: colorScheme.surfaceContainerHigh,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [SliverFillRemaining(hasScrollBody: false, child: child)],
      ),
    );
  }
}
