import 'package:flutter/material.dart';

/// One choice of a [SegmentedPill]: visible as [label] or [icon], and named
/// [semanticLabel] for assistive technology and tooltips.
typedef PillSegment<T> = ({
  T value,
  String? label,
  IconData? icon,
  String semanticLabel,
});

/// A compact single-choice toggle shaped as a pill.
class SegmentedPill<T> extends StatelessWidget {
  /// Smallest tap target on either axis.
  static const double _minTarget = 48;

  final List<PillSegment<T>> segments;
  final T selected;
  final ValueChanged<T> onSelected;

  const SegmentedPill({
    super.key,
    required this.segments,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final radius = BorderRadius.circular(_minTarget / 2);

    return Material(
      color: colorScheme.surfaceContainerHighest,
      borderRadius: radius,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final segment in segments)
            Tooltip(
              message: segment.semanticLabel,
              excludeFromSemantics: true,
              child: Semantics(
                container: true,
                button: true,
                inMutuallyExclusiveGroup: true,
                selected: segment.value == selected,
                label: segment.semanticLabel,
                excludeSemantics: true,
                onTap: () => onSelected(segment.value),
                child: InkWell(
                  borderRadius: radius,
                  onTap: () => onSelected(segment.value),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      minWidth: _minTarget,
                      minHeight: _minTarget,
                    ),
                    child: Center(
                      widthFactor: 1,
                      heightFactor: 1,
                      child: Container(
                        constraints: const BoxConstraints(
                          minWidth: 40,
                          minHeight: 40,
                        ),
                        margin: const EdgeInsets.all(4),
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        decoration: BoxDecoration(
                          color: segment.value == selected
                              ? colorScheme.primary
                              : colorScheme.surfaceContainerHighest,
                          borderRadius: radius,
                        ),
                        child: Center(
                          widthFactor: 1,
                          heightFactor: 1,
                          child: segment.icon != null
                              ? Icon(
                                  segment.icon,
                                  size: 20,
                                  color: segment.value == selected
                                      ? colorScheme.onPrimary
                                      : colorScheme.onSurfaceVariant,
                                )
                              : Text(
                                  segment.label!,
                                  style: theme.textTheme.labelLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: segment.value == selected
                                        ? colorScheme.onPrimary
                                        : colorScheme.onSurfaceVariant,
                                  ),
                                ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
