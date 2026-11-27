import 'dart:math' as math;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../constants/material3_config.dart';

/// A GoRouter [Page] that presents its [child] inside a translucent
/// [DialogRoute].
///
/// When pushed on top of an existing route, the underlying screen remains
/// visible behind the scrim and dismissing pops back to it. When opened via a
/// direct URL cold load (no underlying route), the modal renders over a themed
/// backdrop and dismissing navigates to [fallbackRoute].
class ModalDialogPage<T> extends Page<T> {
  const ModalDialogPage({
    required this.child,
    super.key,
    super.name,
    super.arguments,
    super.restorationId,
    this.barrierDismissible = true,
    this.barrierLabel,
    this.barrierColor,
    this.fallbackRoute = '/',
  });

  final Widget child;
  final bool barrierDismissible;
  final String? barrierLabel;
  final Color? barrierColor;
  final String fallbackRoute;

  @override
  Route<T> createRoute(BuildContext context) {
    final scrimColor = barrierColor ?? Colors.black.withValues(alpha: 0.4);
    return DialogRoute<T>(
      context: context,
      settings: this,
      useSafeArea: false,
      barrierDismissible: barrierDismissible,
      barrierLabel:
          barrierLabel ??
          MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: scrimColor,
      builder: (routeContext) {
        final isStandalone = ModalRoute.of(routeContext)?.isFirst ?? false;
        if (!isStandalone) {
          return SafeArea(child: child);
        }
        return _StandaloneModalHost(
          scrimColor: scrimColor,
          barrierDismissible: barrierDismissible,
          onDismiss: () => UrlModalDialog.dismiss(
            routeContext,
            fallbackRoute: fallbackRoute,
          ),
          child: child,
        );
      },
    );
  }
}

/// Footer cross-link shown inside a [UrlModalDialog].
class UrlModalLink {
  const UrlModalLink({required this.label, required this.location});

  final String label;
  final String location;
}

/// Small centered modal frame backed by a URL route.
///
/// Sized to match lightweight form modals (~460px max width, 16px corners)
/// rather than a full-width stretched page.
class UrlModalDialog extends StatelessWidget {
  const UrlModalDialog({
    super.key,
    required this.title,
    required this.icon,
    required this.child,
    this.iconColor,
    this.routeBadge,
    this.footerLinks = const [],
    this.showCloseButton = true,
    this.primaryCloseButton = true,
    this.fallbackRoute = '/',
    this.onClose,
  });

  static const double maxWidth = 460;
  static const double maxHeight = 640;
  static const double borderRadius = Material3Config.radiusLarge;

  final String title;
  final IconData icon;
  final Color? iconColor;
  final String? routeBadge;
  final Widget child;
  final List<UrlModalLink> footerLinks;
  final bool showCloseButton;
  final bool primaryCloseButton;
  final String fallbackRoute;
  final VoidCallback? onClose;

  /// Pops the current modal when opened from within the app, or falls back to
  /// [fallbackRoute] when opened directly by URL.
  static void dismiss(BuildContext context, {String fallbackRoute = '/'}) {
    final router = GoRouter.maybeOf(context);
    if (router != null) {
      if (router.canPop()) {
        router.pop();
      } else {
        router.go(fallbackRoute);
      }
      return;
    }
    Navigator.of(context).maybePop();
  }

  /// Switches between URL-backed modals without stacking duplicates over the
  /// underlying screen.
  static void navigateToModal(BuildContext context, String location) {
    final router = GoRouter.of(context);
    if (router.canPop()) {
      router.pushReplacement(location);
    } else {
      router.go(location);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final viewportHeight = MediaQuery.sizeOf(context).height;
    final effectiveMaxHeight = math.min(maxHeight, viewportHeight * 0.85);
    final handleClose =
        onClose ?? () => dismiss(context, fallbackRoute: fallbackRoute);

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      backgroundColor: colorScheme.surface,
      surfaceTintColor: Colors.transparent,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(borderRadius),
        side: BorderSide(
          color: colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Semantics(
        identifier: 'url-modal-card',
        container: true,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: maxWidth,
            maxHeight: effectiveMaxHeight,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _UrlModalHeader(
                icon: icon,
                iconColor: iconColor,
                title: title,
                routeBadge: routeBadge,
                onClose: handleClose,
              ),
              const Divider(height: 1),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                  child: child,
                ),
              ),
              if (footerLinks.isNotEmpty || showCloseButton) ...[
                const Divider(height: 1),
                _UrlModalFooter(
                  links: footerLinks,
                  showCloseButton: showCloseButton,
                  primaryCloseButton: primaryCloseButton,
                  onClose: handleClose,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _UrlModalHeader extends StatelessWidget {
  const _UrlModalHeader({
    required this.icon,
    required this.title,
    required this.onClose,
    this.iconColor,
    this.routeBadge,
  });

  final IconData icon;
  final Color? iconColor;
  final String title;
  final String? routeBadge;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final showBadge =
        routeBadge != null && MediaQuery.sizeOf(context).width >= 400;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 8, 8),
      child: Row(
        children: [
          Icon(icon, size: 22, color: iconColor ?? colorScheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Semantics(
              header: true,
              child: Text(
                title,
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          if (showBadge) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                routeBadge!,
                style: textTheme.labelSmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
          const SizedBox(width: 4),
          IconButton(
            key: const Key('url_modal_close_icon'),
            icon: const Icon(Icons.close),
            tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
            onPressed: onClose,
          ),
        ],
      ),
    );
  }
}

class _UrlModalFooter extends StatelessWidget {
  const _UrlModalFooter({
    required this.links,
    required this.showCloseButton,
    required this.primaryCloseButton,
    required this.onClose,
  });

  final List<UrlModalLink> links;
  final bool showCloseButton;
  final bool primaryCloseButton;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Wrap(
              spacing: 4,
              runSpacing: 4,
              children: [
                for (final link in links)
                  TextButton(
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 6,
                      ),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    onPressed: () =>
                        UrlModalDialog.navigateToModal(context, link.location),
                    child: Text(link.label),
                  ),
              ],
            ),
          ),
          if (showCloseButton) ...[
            const SizedBox(width: 8),
            if (primaryCloseButton)
              FilledButton(onPressed: onClose, child: Text('common.close'.tr()))
            else
              TextButton(onPressed: onClose, child: Text('common.close'.tr())),
          ],
        ],
      ),
    );
  }
}

class _StandaloneModalHost extends StatelessWidget {
  const _StandaloneModalHost({
    required this.scrimColor,
    required this.barrierDismissible,
    required this.onDismiss,
    required this.child,
  });

  final Color scrimColor;
  final bool barrierDismissible;
  final VoidCallback onDismiss;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return CallbackShortcuts(
      bindings: barrierDismissible
          ? {const SingleActivator(LogicalKeyboardKey.escape): onDismiss}
          : const {},
      child: Focus(
        autofocus: true,
        child: Scaffold(
          backgroundColor: colorScheme.surface,
          body: Stack(
            fit: StackFit.expand,
            children: [
              const _StandaloneModalBackdrop(),
              Positioned.fill(
                child: GestureDetector(
                  key: const Key('url_modal_standalone_scrim'),
                  behavior: HitTestBehavior.opaque,
                  onTap: barrierDismissible ? onDismiss : null,
                  child: ColoredBox(color: scrimColor),
                ),
              ),
              SafeArea(child: child),
            ],
          ),
        ),
      ),
    );
  }
}

class _StandaloneModalBackdrop extends StatelessWidget {
  const _StandaloneModalBackdrop();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final cardDecoration = BoxDecoration(
      color: colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(Material3Config.radiusMedium),
      border: Border.all(
        color: colorScheme.outlineVariant.withValues(alpha: 0.4),
      ),
    );

    return IgnorePointer(
      child: ExcludeSemantics(
        child: Opacity(
          opacity: 0.45,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1080),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(height: 56, decoration: cardDecoration),
                    const SizedBox(height: 20),
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          if (constraints.maxWidth < 600) {
                            return Column(
                              children: [
                                Container(
                                  height: 160,
                                  decoration: cardDecoration,
                                ),
                                const SizedBox(height: 16),
                                Expanded(
                                  child: Container(decoration: cardDecoration),
                                ),
                              ],
                            );
                          }
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Container(
                                  height: 200,
                                  decoration: cardDecoration,
                                ),
                              ),
                              const SizedBox(width: 20),
                              Expanded(
                                flex: 2,
                                child: Container(
                                  height: 200,
                                  decoration: cardDecoration,
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
