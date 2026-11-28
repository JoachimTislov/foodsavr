import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../constants/adaptive_layout.dart';
import '../../constants/material3_config.dart';
import '../../routes/page_trail.dart';
import '../../utils/app_theme.dart';

/// A single breadcrumb segment resolved from a GoRouter path.
class BreadcrumbItem {
  final String path;
  final String? translationKey;
  final String fallbackLabel;

  const BreadcrumbItem({
    required this.path,
    this.translationKey,
    required this.fallbackLabel,
  });

  /// Returns the localized label when a translation key is mapped, otherwise
  /// falls back to the human-readable segment label.
  String resolveLabel() => translationKey?.tr() ?? fallbackLabel;
}

/// Shows a breadcrumb bar above [child] on windows wider than compact when
/// the current page is nested, including pages pushed on the branch's
/// [trail]. There the breadcrumbs replace the back button
/// ([AppBreadcrumbs.handlesBack]); compact windows show no bar.
class AppBreadcrumbs extends StatelessWidget {
  final Widget child;
  final String? pathOverride;
  final ValueChanged<String>? onNavigate;

  /// Pages pushed on the current branch, appended after the path segments.
  final PageTrail? trail;

  const AppBreadcrumbs({
    super.key,
    required this.child,
    this.pathOverride,
    this.onNavigate,
    this.trail,
  });

  /// Whether a breadcrumb bar above [context] takes the place of its back
  /// button.
  static bool handlesBack(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_BreadcrumbScope>()?.active ??
      false;

  /// Maps known GoRouter path segments to existing translation keys in
  /// `assets/translations/en.json` and `nb.json`.
  static const Map<String, String> segmentTranslationKeys = {
    'dashboard': 'dashboard.title',
    'my-inventory': 'dashboard.myInventory',
    'shopping-lists': 'dashboard.shoppingList',
    'my-products': 'product.all_products',
    'products': 'product.all_products',
    'registry': 'dashboard.globalProducts',
    'receipts': 'receipt.listTitle',
    'transfer': 'transfer.title',
    'transfers': 'transfer.title',
    'settings': 'settings.title',
    'profile': 'profile.title',
    'web-view': 'settings.integrations.title',
    'barcode-scan': 'product.scanBarcode',
    'select-products': 'product.select',
    'privacy': 'settings.privacy_policy',
    'terms': 'settings.terms_of_service',
    'delete-account': 'profile.delete_account',
  };

  /// Parses [rawPath] into ordered [BreadcrumbItem] entries with cumulative
  /// navigation paths.
  static List<BreadcrumbItem> resolveBreadcrumbs(String rawPath) {
    final uri = Uri.tryParse(rawPath);
    final segments = (uri?.pathSegments ?? const <String>[])
        .where((segment) => segment.isNotEmpty)
        .toList();
    if (segments.isEmpty) return const [];

    final items = <BreadcrumbItem>[];
    final buffer = StringBuffer();
    for (final segment in segments) {
      buffer.write('/$segment');
      final normalized = segment.toLowerCase();
      items.add(
        BreadcrumbItem(
          path: buffer.toString(),
          translationKey: segmentTranslationKeys[normalized],
          fallbackLabel: _formatFallback(segment),
        ),
      );
    }
    return items;
  }

  static String _formatFallback(String segment) {
    final words = segment
        .split(RegExp(r'[-_]+'))
        .where((word) => word.isNotEmpty)
        .map(
          (word) =>
              '${word[0].toUpperCase()}${word.length > 1 ? word.substring(1) : ''}',
        )
        .toList();
    return words.isEmpty ? segment : words.join(' ');
  }

  /// Path of the top-most page inside the shell, including imperatively pushed
  /// routes. Root-level routes such as legal modals are ignored.
  static String shellPath(RouteMatchList configuration) {
    final shell = configuration.matches.whereType<ShellRouteMatch>().lastOrNull;
    if (shell == null) return configuration.uri.path;
    RouteMatchBase leaf = shell.matches.last;
    while (leaf is ShellRouteMatch) {
      leaf = leaf.matches.last;
    }
    return leaf is ImperativeRouteMatch
        ? leaf.matches.uri.path
        : leaf.matchedLocation;
  }

  @override
  Widget build(BuildContext context) {
    final delegate = pathOverride == null
        ? GoRouter.maybeOf(context)?.routerDelegate
        : null;
    final trail = this.trail;
    return ListenableBuilder(
      listenable: Listenable.merge([?delegate, ?trail]),
      builder: (context, _) => _buildWithPath(
        context,
        delegate == null
            ? pathOverride ?? ''
            : shellPath(delegate.currentConfiguration),
      ),
    );
  }

  Widget _buildWithPath(BuildContext context, String path) {
    final active = !WindowSize.of(context).isCompact;
    final navigate = onNavigate ?? (target) => context.go(target);
    final pages = trail?.routes ?? const [];
    final crumbs = [
      for (final crumb in resolveBreadcrumbs(path))
        _Crumb(
          label: crumb.resolveLabel(),
          onTap: () {
            trail?.popTo(null);
            navigate(crumb.path);
          },
        ),
      for (final route in pages)
        _Crumb(
          label: route.settings.name ?? '',
          onTap: () => trail?.popTo(route),
        ),
    ];
    final showBar = active && crumbs.length > 1;
    final mediaQuery = MediaQuery.of(context);

    // The tree shape never changes, so [child] keeps its state.
    return Column(
      children: [
        if (showBar)
          _BreadcrumbBar(crumbs: crumbs)
        else
          const SizedBox.shrink(),
        Expanded(
          child: MediaQuery(
            // The bar already consumes the top inset.
            data: showBar
                ? mediaQuery.removePadding(removeTop: true)
                : mediaQuery,
            child: _BreadcrumbScope(active: active, child: child),
          ),
        ),
      ],
    );
  }
}

class _BreadcrumbScope extends InheritedWidget {
  final bool active;

  const _BreadcrumbScope({required this.active, required super.child});

  @override
  bool updateShouldNotify(_BreadcrumbScope oldWidget) =>
      active != oldWidget.active;
}

class _Crumb {
  final String label;
  final VoidCallback onTap;

  const _Crumb({required this.label, required this.onTap});
}

class _BreadcrumbBar extends StatelessWidget {
  final List<_Crumb> crumbs;

  const _BreadcrumbBar({required this.crumbs});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final horizontalPadding = AdaptiveLayout.tokensOf(context).pagePadding.left;

    return Material(
      color: colorScheme.surface,
      child: SafeArea(
        left: false,
        bottom: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Semantics(
              container: true,
              child: Container(
                width: double.infinity,
                constraints: const BoxConstraints(minHeight: 40),
                padding: EdgeInsets.symmetric(
                  horizontal: horizontalPadding,
                  vertical: Material3Config.spacing6,
                ),
                alignment: Alignment.centerLeft,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (var i = 0; i < crumbs.length; i++) ...[
                        if (i > 0)
                          ExcludeSemantics(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: Material3Config.spacing4,
                              ),
                              child: Icon(
                                Icons.chevron_right,
                                size: 16,
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        if (i < crumbs.length - 1)
                          _BreadcrumbLink(
                            label: crumbs[i].label,
                            onTap: crumbs[i].onTap,
                          )
                        else
                          Text(
                            crumbs[i].label,
                            style: theme.textTheme.labelLarge?.copyWith(
                              color: colorScheme.onSurface,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            const Divider(height: 1),
          ],
        ),
      ),
    );
  }
}

class _BreadcrumbLink extends StatefulWidget {
  final String label;
  final VoidCallback onTap;

  const _BreadcrumbLink({required this.label, required this.onTap});

  @override
  State<_BreadcrumbLink> createState() => _BreadcrumbLinkState();
}

class _BreadcrumbLinkState extends State<_BreadcrumbLink> {
  bool _isHovered = false;
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final linkColor = AppTheme.linkColorFor(theme.brightness);
    final hoverColor = AppTheme.linkHoverColorFor(theme.brightness);
    final focusColor = AppTheme.focusRingColorFor(theme.brightness);
    final activeColor = _isHovered ? hoverColor : linkColor;

    // A button node of its own: Flutter web renders a link without a URL as
    // plain text, and giving it one would reload the page on click.
    return Semantics(
      container: true,
      button: true,
      child: InkWell(
        onTap: widget.onTap,
        mouseCursor: SystemMouseCursors.click,
        hoverColor: Colors.transparent,
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        focusColor: Colors.transparent,
        onHover: (hovered) {
          if (_isHovered != hovered) {
            setState(() => _isHovered = hovered);
          }
        },
        onFocusChange: (focused) {
          if (_isFocused != focused) {
            setState(() => _isFocused = focused);
          }
        },
        borderRadius: BorderRadius.circular(Material3Config.radiusDesktopSmall),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: Material3Config.spacing4,
            vertical: Material3Config.spacing4,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(
              Material3Config.radiusDesktopSmall,
            ),
            border: _isFocused
                ? Border.all(
                    color: focusColor,
                    width: Material3Config.focusRingWidth,
                  )
                : null,
          ),
          child: Text(
            widget.label,
            style: theme.textTheme.labelLarge?.copyWith(
              color: activeColor,
              fontWeight: FontWeight.w600,
              decoration: (_isHovered || _isFocused)
                  ? TextDecoration.underline
                  : TextDecoration.none,
              decorationColor: activeColor,
            ),
          ),
        ),
      ),
    );
  }
}
