import 'package:flutter/material.dart';

import '../../constants/adaptive_layout.dart';

/// Centers [child] and limits its width to [maxWidth].
///
/// Place it inside a scroll view so the side gutters still scroll.
class ContentConstraint extends StatelessWidget {
  final double maxWidth;
  final Widget child;

  const ContentConstraint({
    super.key,
    this.maxWidth = AdaptiveLayout.pageMaxWidth,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}

/// Sliver counterpart of [ContentConstraint]: lays out [slivers] in a centered
/// column of at most [maxWidth].
class SliverContentConstraint extends StatelessWidget {
  final double maxWidth;
  final List<Widget> slivers;

  const SliverContentConstraint({
    super.key,
    this.maxWidth = AdaptiveLayout.pageMaxWidth,
    required this.slivers,
  });

  @override
  Widget build(BuildContext context) {
    return SliverLayoutBuilder(
      builder: (context, constraints) => SliverPadding(
        padding: EdgeInsets.symmetric(
          horizontal: AdaptiveLayout.gutterFor(
            constraints.crossAxisExtent,
            maxWidth,
          ),
        ),
        sliver: SliverMainAxisGroup(slivers: slivers),
      ),
    );
  }
}
