import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foodsavr/constants/adaptive_layout.dart';
import 'package:foodsavr/constants/material3_config.dart';
import 'package:foodsavr/utils/app_theme.dart';

void main() {
  group('AppTheme link styling (#16)', () {
    test(
      'text buttons drop filled hover overlay and use darker link colors',
      () {
        final lightStyle = AppTheme.lightTheme.textButtonTheme.style!;
        final darkStyle = AppTheme.darkTheme.textButtonTheme.style!;

        expect(
          lightStyle.overlayColor?.resolve({WidgetState.hovered}),
          Colors.transparent,
        );
        expect(
          darkStyle.overlayColor?.resolve({WidgetState.hovered}),
          Colors.transparent,
        );

        expect(
          lightStyle.foregroundColor?.resolve({}),
          AppTheme.lightLinkColor,
        );
        expect(
          lightStyle.foregroundColor?.resolve({WidgetState.hovered}),
          AppTheme.lightLinkHoverColor,
        );
        expect(darkStyle.foregroundColor?.resolve({}), AppTheme.darkLinkColor);
        expect(
          darkStyle.foregroundColor?.resolve({WidgetState.hovered}),
          AppTheme.darkLinkHoverColor,
        );
      },
    );

    test('text links show underline on hover/focus and pointer cursor', () {
      final style = AppTheme.lightTheme.textButtonTheme.style!;

      expect(style.textStyle?.resolve({})?.decoration, TextDecoration.none);
      expect(
        style.textStyle?.resolve({WidgetState.hovered})?.decoration,
        TextDecoration.underline,
      );
      expect(
        style.textStyle?.resolve({WidgetState.focused})?.decoration,
        TextDecoration.underline,
      );
      expect(style.mouseCursor?.resolve({}), SystemMouseCursors.click);
      expect(
        style.mouseCursor?.resolve({WidgetState.disabled}),
        SystemMouseCursors.basic,
      );
    });
  });

  group('AppTheme desktop interaction affordances (#34)', () {
    test('interactive button themes expose click cursor and focus ring', () {
      final theme = AppTheme.themeFor(Brightness.light, WindowSize.expanded);
      final styles = [
        theme.textButtonTheme.style!,
        theme.filledButtonTheme.style!,
        theme.outlinedButtonTheme.style!,
        theme.elevatedButtonTheme.style!,
        theme.iconButtonTheme.style!,
      ];

      for (final style in styles) {
        expect(style.mouseCursor?.resolve({}), SystemMouseCursors.click);
        expect(
          style.mouseCursor?.resolve({WidgetState.disabled}),
          SystemMouseCursors.basic,
        );
        final focusedSide = style.side?.resolve({WidgetState.focused});
        expect(focusedSide, isNotNull);
        expect(focusedSide!.width, Material3Config.focusRingWidth);
        expect(focusedSide.style, BorderStyle.solid);
      }
    });

    test('list tiles and chips expose desktop interaction states', () {
      final theme = AppTheme.themeFor(Brightness.light, WindowSize.expanded);
      expect(theme.listTileTheme.mouseCursor, WidgetStateMouseCursor.clickable);

      final chipSide = theme.chipTheme.side;
      expect(chipSide, isA<WidgetStateBorderSide>());
      final widgetStateSide = chipSide! as WidgetStateBorderSide;
      expect(
        widgetStateSide.resolve({WidgetState.focused})?.width,
        Material3Config.focusRingWidth,
      );
      expect(
        widgetStateSide.resolve({WidgetState.hovered})?.style,
        BorderStyle.solid,
      );
    });
  });

  group('AppTheme responsive radii (#5)', () {
    test('desktop theme uses crisper radii than mobile theme', () {
      final mobile = AppTheme.themeFor(Brightness.light, WindowSize.compact);
      final desktop = AppTheme.themeFor(Brightness.light, WindowSize.expanded);

      final mobileCard = mobile.cardTheme.shape! as RoundedRectangleBorder;
      final desktopCard = desktop.cardTheme.shape! as RoundedRectangleBorder;
      final mobileRadius = (mobileCard.borderRadius as BorderRadius).topLeft.x;
      final desktopRadius =
          (desktopCard.borderRadius as BorderRadius).topLeft.x;

      expect(mobileRadius, Material3Config.radiusLarge);
      expect(desktopRadius, Material3Config.radiusDesktopLarge);
      expect(desktopRadius, lessThan(mobileRadius));
    });

    test('themeFor applies desktop card and input radii in dark mode', () {
      final adapted = AppTheme.themeFor(Brightness.dark, WindowSize.expanded);
      expect(adapted.brightness, Brightness.dark);
      final cardShape = adapted.cardTheme.shape! as RoundedRectangleBorder;
      expect(
        (cardShape.borderRadius as BorderRadius).topLeft.x,
        Material3Config.radiusDesktopLarge,
      );
      final inputBorder =
          adapted.inputDecorationTheme.enabledBorder! as OutlineInputBorder;
      expect(
        inputBorder.borderRadius.topLeft.x,
        Material3Config.radiusDesktopMedium,
      );
    });
  });
}
