import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foodsavr/constants/adaptive_layout.dart';
import 'package:foodsavr/utils/platform_capabilities.dart';

void main() {
  tearDown(() {
    PlatformCapabilities.testSignalsOverride = null;
  });

  test('classifies desktop web browser with fine pointer as desktop', () {
    final caps = PlatformCapabilities.resolve(
      viewportWidth: 1280,
      signals: const PlatformCapabilitySignals(
        userAgentMobile: false,
        hasCoarsePointer: false,
        hasFinePointer: true,
        maxTouchPoints: 0,
        isWeb: true,
      ),
    );

    expect(caps.windowSize, WindowSize.expanded);
    expect(caps.isTouchPrimary, isFalse);
    expect(caps.isDesktopPointer, isTrue);
    expect(caps.formFactor, DeviceFormFactor.desktop);
    expect(caps.preferDesktopAffordances, isTrue);
  });

  test('classifies mobile web browser with userAgentMobile true as mobile', () {
    final caps = PlatformCapabilities.resolve(
      viewportWidth: 412,
      signals: const PlatformCapabilitySignals(
        userAgentMobile: true,
        hasCoarsePointer: true,
        hasFinePointer: false,
        maxTouchPoints: 5,
        isWeb: true,
      ),
    );

    expect(caps.windowSize, WindowSize.compact);
    expect(caps.isTouchPrimary, isTrue);
    expect(caps.isDesktopPointer, isFalse);
    expect(caps.formFactor, DeviceFormFactor.mobile);
    expect(caps.preferDesktopAffordances, isFalse);
  });

  test('classifies touch-only tablet in landscape as tablet form factor', () {
    final caps = PlatformCapabilities.resolve(
      viewportWidth: 1024,
      signals: const PlatformCapabilitySignals(
        userAgentMobile: false,
        hasCoarsePointer: true,
        hasFinePointer: false,
        maxTouchPoints: 5,
        isWeb: true,
      ),
    );

    expect(caps.isTouchPrimary, isTrue);
    expect(caps.formFactor, DeviceFormFactor.tablet);
  });

  test('classifies touchscreen laptop with fine pointer as desktop', () {
    final caps = PlatformCapabilities.resolve(
      viewportWidth: 1440,
      signals: const PlatformCapabilitySignals(
        userAgentMobile: false,
        hasCoarsePointer: false,
        hasFinePointer: true,
        maxTouchPoints: 10,
        isWeb: true,
      ),
    );

    expect(caps.isTouchPrimary, isFalse);
    expect(caps.isDesktopPointer, isTrue);
    expect(caps.formFactor, DeviceFormFactor.desktop);
  });

  test(
    'narrow desktop browser window falls back to the mobile form factor',
    () {
      final caps = PlatformCapabilities.resolve(
        viewportWidth: 480,
        signals: const PlatformCapabilitySignals(
          userAgentMobile: false,
          hasCoarsePointer: false,
          hasFinePointer: true,
          maxTouchPoints: 0,
          isWeb: true,
        ),
      );

      expect(caps.windowSize, WindowSize.compact);
      expect(caps.formFactor, DeviceFormFactor.mobile);
    },
  );

  testWidgets(
    'PlatformCapabilities.of reads viewport width and test override',
    (tester) async {
      PlatformCapabilities.testSignalsOverride =
          const PlatformCapabilitySignals(
            userAgentMobile: false,
            hasCoarsePointer: false,
            hasFinePointer: true,
            maxTouchPoints: 0,
            isWeb: true,
          );

      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      late PlatformCapabilities resolved;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              resolved = PlatformCapabilities.of(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      expect(resolved.viewportWidth, 1280);
      expect(resolved.isDesktopPointer, isTrue);
    },
  );
}
