import 'package:flutter/material.dart';

import '../constants/adaptive_layout.dart';
import '../constants/material3_config.dart';

/// Centralized theme configuration for the FoodSavr application.
/// Implements Material 3 design principles, dynamic theming, responsive radii,
/// and consistent desktop/mobile interaction affordances.
class AppTheme {
  /// LettMat brand cyan, also the color scheme seed.
  static const brandColor = Color(0xFF13c8ec);

  /// Foreground on [brandColor] in both themes.
  static const onBrandColor = Color(0xFF0f172a);

  /// High-contrast deep teal for text links in light mode (>7:1 on light surface).
  static const lightLinkColor = Color(0xFF085A73);

  /// Darker deep teal for hovered/pressed text links in light mode.
  static const lightLinkHoverColor = Color(0xFF054357);

  /// High-contrast crisp cyan for text links in dark mode (>10:1 on dark surface).
  static const darkLinkColor = Color(0xFF67E2F7);

  /// Brightened cyan for hovered/pressed text links in dark mode.
  static const darkLinkHoverColor = Color(0xFF9BEEFC);

  // Background overrides if necessary, though ColorScheme.fromSeed handles these well
  static const _lightBackground = Color(0xFFf6f8f8);
  static const _darkBackground = Color(0xFF101f22);

  static final WidgetStateProperty<MouseCursor> _clickableCursor =
      WidgetStateProperty.resolveWith<MouseCursor>(
        (states) => states.contains(WidgetState.disabled)
            ? SystemMouseCursors.basic
            : SystemMouseCursors.click,
      );

  /// Primary text-link color for [brightness].
  static Color linkColorFor(Brightness brightness) =>
      brightness == Brightness.dark ? darkLinkColor : lightLinkColor;

  /// Hover/pressed text-link color for [brightness].
  static Color linkHoverColorFor(Brightness brightness) =>
      brightness == Brightness.dark ? darkLinkHoverColor : lightLinkHoverColor;

  /// High-contrast keyboard focus ring color for [brightness].
  static Color focusRingColorFor(Brightness brightness) =>
      linkColorFor(brightness);

  /// Standard Typography Scale for consistent text hierarchy
  static TextTheme _buildTextTheme(TextTheme base, Color textColor) {
    return base.copyWith(
      displayLarge: base.displayLarge?.copyWith(
        fontSize: 57,
        fontWeight: FontWeight.w400,
        letterSpacing: -0.25,
        color: textColor,
      ),
      displayMedium: base.displayMedium?.copyWith(
        fontSize: 45,
        fontWeight: FontWeight.w400,
        color: textColor,
      ),
      displaySmall: base.displaySmall?.copyWith(
        fontSize: 36,
        fontWeight: FontWeight.w400,
        color: textColor,
      ),
      headlineLarge: base.headlineLarge?.copyWith(
        fontSize: 32,
        fontWeight: FontWeight.w400,
        color: textColor,
      ),
      headlineMedium: base.headlineMedium?.copyWith(
        fontSize: 28,
        fontWeight: FontWeight.w400,
        color: textColor,
      ),
      headlineSmall: base.headlineSmall?.copyWith(
        fontSize: 24,
        fontWeight: FontWeight.w500,
        color: textColor,
      ),
      titleLarge: base.titleLarge?.copyWith(
        fontSize: 22,
        fontWeight: FontWeight.w500,
        color: textColor,
      ),
      titleMedium: base.titleMedium?.copyWith(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.15,
        color: textColor,
      ),
      titleSmall: base.titleSmall?.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.1,
        color: textColor,
      ),
      bodyLarge: base.bodyLarge?.copyWith(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.5,
        color: textColor,
      ),
      bodyMedium: base.bodyMedium?.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.25,
        color: textColor,
      ),
      bodySmall: base.bodySmall?.copyWith(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.4,
        color: textColor,
      ),
      labelLarge: base.labelLarge?.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.1,
        color: textColor,
      ),
      labelMedium: base.labelMedium?.copyWith(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.5,
        color: textColor,
      ),
      labelSmall: base.labelSmall?.copyWith(
        fontSize: 11,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.5,
        color: textColor,
      ),
    );
  }

  /// Text-link [ButtonStyle] with no filled button highlight, dark high-contrast
  /// foreground, subtle hover underline, pointer cursor, and keyboard focus ring.
  static ButtonStyle _linkButtonStyle({
    required ColorScheme colorScheme,
    required TextTheme textTheme,
    required double radius,
  }) {
    final linkColor = linkColorFor(colorScheme.brightness);
    final hoverColor = linkHoverColorFor(colorScheme.brightness);
    final focusColor = focusRingColorFor(colorScheme.brightness);
    final baseLabel = textTheme.labelLarge?.copyWith(
      fontWeight: FontWeight.w600,
    );

    return ButtonStyle(
      padding: const WidgetStatePropertyAll<EdgeInsetsGeometry>(
        EdgeInsets.symmetric(
          horizontal: Material3Config.spacing12,
          vertical: Material3Config.spacing8,
        ),
      ),
      shape: WidgetStatePropertyAll<OutlinedBorder>(
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius)),
      ),
      overlayColor: const WidgetStatePropertyAll<Color>(Colors.transparent),
      mouseCursor: _clickableCursor,
      foregroundColor: WidgetStateProperty.resolveWith<Color>((states) {
        if (states.contains(WidgetState.disabled)) {
          return colorScheme.onSurface.withValues(alpha: 0.38);
        }
        if (states.contains(WidgetState.hovered) ||
            states.contains(WidgetState.pressed)) {
          return hoverColor;
        }
        return linkColor;
      }),
      textStyle: WidgetStateProperty.resolveWith<TextStyle?>((states) {
        final showUnderline =
            !states.contains(WidgetState.disabled) &&
            (states.contains(WidgetState.hovered) ||
                states.contains(WidgetState.focused));
        return baseLabel?.copyWith(
          decoration: showUnderline
              ? TextDecoration.underline
              : TextDecoration.none,
          decorationColor: hoverColor,
        );
      }),
      side: WidgetStateProperty.resolveWith<BorderSide>((states) {
        if (states.contains(WidgetState.focused)) {
          return BorderSide(
            color: focusColor,
            width: Material3Config.focusRingWidth,
          );
        }
        return BorderSide.none;
      }),
    );
  }

  /// Shared component themes to ensure consistency across light and dark modes.
  static ThemeData _applySharedComponentThemes(
    ThemeData base, {
    WindowSize windowSize = WindowSize.compact,
  }) {
    final colorScheme = base.colorScheme;
    final tokens = AdaptiveLayout.tokensFor(windowSize);
    final isDesktop = windowSize.isExpanded;
    final focusColor = focusRingColorFor(colorScheme.brightness);
    final buttonRadius = isDesktop ? tokens.controlRadius : tokens.cardRadius;
    final buttonPadding = EdgeInsets.symmetric(
      horizontal: tokens.buttonHorizontalPadding,
      vertical: tokens.buttonVerticalPadding,
    );
    final buttonShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(buttonRadius),
    );
    final buttonTextStyle = base.textTheme.labelLarge?.copyWith(
      fontWeight: FontWeight.w600,
    );

    return base.copyWith(
      hoverColor: colorScheme.primary.withValues(alpha: 0.06),
      focusColor: focusColor.withValues(alpha: 0.14),
      appBarTheme: AppBarTheme(
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
        centerTitle: false,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: base.textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: isDesktop
            ? Material3Config.elevationLevel0
            : Material3Config.elevationLevel1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(tokens.cardRadius),
          side: isDesktop
              ? BorderSide(
                  color: colorScheme.outlineVariant.withValues(alpha: 0.7),
                )
              : BorderSide.none,
        ),
        color: colorScheme.surface,
        surfaceTintColor: colorScheme.surfaceTint,
        margin: EdgeInsets.symmetric(
          horizontal: isDesktop
              ? Material3Config.spacing12
              : Material3Config.spacing16,
          vertical: Material3Config.spacing8,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style:
            ElevatedButton.styleFrom(
              elevation: Material3Config.elevationLevel1,
              padding: buttonPadding,
              shape: buttonShape,
              backgroundColor: colorScheme.primary,
              foregroundColor: colorScheme.onPrimary,
              textStyle: buttonTextStyle,
            ).copyWith(
              mouseCursor: _clickableCursor,
              elevation: WidgetStateProperty.resolveWith<double>((states) {
                if (states.contains(WidgetState.disabled)) {
                  return Material3Config.elevationLevel0;
                }
                if (states.contains(WidgetState.hovered)) {
                  return Material3Config.elevationLevel2;
                }
                return Material3Config.elevationLevel1;
              }),
              side: WidgetStateProperty.resolveWith<BorderSide>((states) {
                if (states.contains(WidgetState.focused)) {
                  return BorderSide(
                    color: focusColor,
                    width: Material3Config.focusRingWidth,
                  );
                }
                return BorderSide.none;
              }),
            ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style:
            FilledButton.styleFrom(
              padding: buttonPadding,
              shape: buttonShape,
              textStyle: buttonTextStyle,
            ).copyWith(
              mouseCursor: _clickableCursor,
              overlayColor: WidgetStateProperty.resolveWith<Color?>((states) {
                if (states.contains(WidgetState.hovered)) {
                  return colorScheme.onPrimary.withValues(alpha: 0.08);
                }
                if (states.contains(WidgetState.pressed)) {
                  return colorScheme.onPrimary.withValues(alpha: 0.14);
                }
                return null;
              }),
              side: WidgetStateProperty.resolveWith<BorderSide>((states) {
                if (states.contains(WidgetState.focused)) {
                  return BorderSide(
                    color: colorScheme.onSurface,
                    width: Material3Config.focusRingWidth,
                  );
                }
                return BorderSide.none;
              }),
            ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style:
            OutlinedButton.styleFrom(
              padding: buttonPadding,
              shape: buttonShape,
              side: BorderSide(color: colorScheme.outline),
              textStyle: buttonTextStyle,
            ).copyWith(
              mouseCursor: _clickableCursor,
              overlayColor: WidgetStateProperty.resolveWith<Color?>((states) {
                if (states.contains(WidgetState.hovered)) {
                  return colorScheme.primary.withValues(alpha: 0.06);
                }
                if (states.contains(WidgetState.pressed)) {
                  return colorScheme.primary.withValues(alpha: 0.12);
                }
                return null;
              }),
              side: WidgetStateProperty.resolveWith<BorderSide>((states) {
                if (states.contains(WidgetState.disabled)) {
                  return BorderSide(
                    color: colorScheme.outline.withValues(alpha: 0.38),
                  );
                }
                if (states.contains(WidgetState.focused)) {
                  return BorderSide(
                    color: focusColor,
                    width: Material3Config.focusRingWidth,
                  );
                }
                if (states.contains(WidgetState.hovered)) {
                  return BorderSide(color: focusColor, width: 1.5);
                }
                return BorderSide(color: colorScheme.outline);
              }),
            ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: _linkButtonStyle(
          colorScheme: colorScheme,
          textTheme: base.textTheme,
          radius: tokens.controlRadius,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: ButtonStyle(
          mouseCursor: _clickableCursor,
          overlayColor: WidgetStateProperty.resolveWith<Color?>((states) {
            if (states.contains(WidgetState.hovered)) {
              return colorScheme.onSurface.withValues(alpha: 0.08);
            }
            if (states.contains(WidgetState.pressed)) {
              return colorScheme.onSurface.withValues(alpha: 0.14);
            }
            return null;
          }),
          side: WidgetStateProperty.resolveWith<BorderSide>((states) {
            if (states.contains(WidgetState.focused)) {
              return BorderSide(
                color: focusColor,
                width: Material3Config.focusRingWidth,
              );
            }
            return BorderSide.none;
          }),
        ),
      ),
      listTileTheme: ListTileThemeData(
        mouseCursor: WidgetStateMouseCursor.clickable,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(tokens.controlRadius),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(tokens.controlRadius),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(tokens.controlRadius),
          borderSide: BorderSide(color: colorScheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(tokens.controlRadius),
          borderSide: BorderSide(
            color: focusColor,
            width: Material3Config.focusRingWidth,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(tokens.controlRadius),
          borderSide: BorderSide(color: colorScheme.error),
        ),
        contentPadding: const EdgeInsets.all(Material3Config.spacing16),
        labelStyle: base.textTheme.bodyLarge,
        hintStyle: base.textTheme.bodyLarge?.copyWith(
          color: colorScheme.onSurfaceVariant,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: colorScheme.surface,
        indicatorColor: colorScheme.secondaryContainer,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return base.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface,
            );
          }
          return base.textTheme.labelMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return IconThemeData(color: colorScheme.onSecondaryContainer);
          }
          return IconThemeData(color: colorScheme.onSurfaceVariant);
        }),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: colorScheme.secondaryContainer,
        labelStyle: base.textTheme.labelLarge?.copyWith(
          color: colorScheme.onSecondaryContainer,
        ),
        secondaryLabelStyle: base.textTheme.labelLarge?.copyWith(
          color: colorScheme.onPrimary,
        ),
        padding: const EdgeInsets.all(Material3Config.spacing4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(tokens.chipRadius),
        ),
        side: WidgetStateBorderSide.resolveWith((states) {
          if (states.contains(WidgetState.focused)) {
            return BorderSide(
              color: focusColor,
              width: Material3Config.focusRingWidth,
            );
          }
          if (states.contains(WidgetState.hovered)) {
            return BorderSide(color: colorScheme.outline);
          }
          return BorderSide.none;
        }),
      ),
      dividerTheme: DividerThemeData(
        color: colorScheme.outlineVariant,
        thickness: 1,
        space: 1,
      ),
    );
  }

  /// Light Theme Definition (compact scale).
  static ThemeData get lightTheme => _light(WindowSize.compact);

  /// Dark Theme Definition (compact scale).
  static ThemeData get darkTheme => _dark(WindowSize.compact);

  /// Theme with the radii and spacing for [windowSize]. Built from the source
  /// definitions, never from a localized theme, so component text styles stay
  /// interpolatable when the window crosses a breakpoint.
  static ThemeData themeFor(Brightness brightness, WindowSize windowSize) =>
      brightness == Brightness.dark ? _dark(windowSize) : _light(windowSize);

  static ThemeData _light(WindowSize windowSize) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: brandColor,
      brightness: Brightness.light,
      surface: _lightBackground,
    );

    final base = ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      brightness: Brightness.light,
      scaffoldBackgroundColor: colorScheme.surface,
    );

    return _applySharedComponentThemes(
      base.copyWith(
        textTheme: _buildTextTheme(base.textTheme, colorScheme.onSurface),
      ),
      windowSize: windowSize,
    );
  }

  static ThemeData _dark(WindowSize windowSize) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: brandColor,
      brightness: Brightness.dark,
      surface: _darkBackground,
    );

    final base = ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: colorScheme.surface,
    );

    return _applySharedComponentThemes(
      base.copyWith(
        textTheme: _buildTextTheme(base.textTheme, colorScheme.onSurface),
      ),
      windowSize: windowSize,
    );
  }
}
