import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foodsavr/controllers/pwa_install_controller.dart';
import 'package:foodsavr/widgets/common/pwa_install_banner.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

class _FakePwaBridge implements PwaBridge {
  _FakePwaBridge({
    this.isSupported = true,
    this.isInstalled = false,
    this.canPrompt = false,
    this.platformHint = PwaPlatformHint.standard,
    this.nextPromptResult = PwaPromptResult.accepted,
  });

  @override
  bool isSupported;

  @override
  bool isInstalled;

  @override
  bool canPrompt;

  @override
  PwaPlatformHint platformHint;

  PwaPromptResult nextPromptResult;
  int promptCallCount = 0;
  bool disposed = false;

  final StreamController<void> _controller = StreamController<void>.broadcast();

  void emitChange() {
    _controller.add(null);
  }

  @override
  Stream<void> get onStateChanged => _controller.stream;

  @override
  Future<PwaPromptResult> promptInstall() async {
    promptCallCount++;
    if (nextPromptResult == PwaPromptResult.accepted) {
      isInstalled = true;
      canPrompt = false;
    }
    return nextPromptResult;
  }

  @override
  void dispose() {
    disposed = true;
    _controller.close();
  }
}

Widget _wrapWithLocalization(Widget child) {
  return EasyLocalization(
    supportedLocales: const [Locale('en'), Locale('nb')],
    path: 'assets/translations',
    fallbackLocale: const Locale('en'),
    child: Builder(
      builder: (context) => MaterialApp(
        localizationsDelegates: context.localizationDelegates,
        supportedLocales: context.supportedLocales,
        locale: context.locale,
        home: Scaffold(body: child),
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  EasyLocalization.logger.enableBuildModes = [];
  EasyLocalization.logger.enableLevels = [];

  late SharedPreferencesWithCache prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.withData({});
    prefs = await SharedPreferencesWithCache.create(
      cacheOptions: const SharedPreferencesWithCacheOptions(
        allowList: {PwaInstallController.kDismissedKey},
      ),
    );
  });

  group('PwaInstallController', () {
    test('disabled factory reports unsupported and hides banner', () {
      final controller = PwaInstallController.disabled();
      addTearDown(controller.dispose);

      expect(controller.isSupported, isFalse);
      expect(controller.isInstalled, isFalse);
      expect(controller.canInstall, isFalse);
      expect(controller.shouldShowBanner, isFalse);
    });

    test('reports installable on web when not yet installed', () {
      final bridge = _FakePwaBridge(isSupported: true, isInstalled: false);
      final controller = PwaInstallController(bridge: bridge, prefs: prefs);
      addTearDown(controller.dispose);

      expect(controller.isSupported, isTrue);
      expect(controller.canInstall, isTrue);
      expect(controller.shouldShowBanner, isTrue);
    });

    test('hides banner when running in installed standalone mode', () {
      final bridge = _FakePwaBridge(isSupported: true, isInstalled: true);
      final controller = PwaInstallController(bridge: bridge, prefs: prefs);
      addTearDown(controller.dispose);

      expect(controller.isInstalled, isTrue);
      expect(controller.canInstall, isFalse);
      expect(controller.shouldShowBanner, isFalse);
    });

    test('triggers native prompt when canPrompt is true', () async {
      final bridge = _FakePwaBridge(
        canPrompt: true,
        nextPromptResult: PwaPromptResult.accepted,
      );
      final controller = PwaInstallController(bridge: bridge, prefs: prefs);
      addTearDown(controller.dispose);

      final result = await controller.requestInstall();

      expect(result, PwaPromptResult.accepted);
      expect(bridge.promptCallCount, 1);
      expect(controller.isInstalled, isTrue);
      expect(controller.shouldShowBanner, isFalse);
    });

    test('returns unavailable when native prompt is not ready', () async {
      final bridge = _FakePwaBridge(canPrompt: false);
      final controller = PwaInstallController(bridge: bridge, prefs: prefs);
      addTearDown(controller.dispose);

      final result = await controller.requestInstall();

      expect(result, PwaPromptResult.unavailable);
      expect(bridge.promptCallCount, 0);
    });

    test('notifies listeners when bridge emits state change', () async {
      final bridge = _FakePwaBridge(canPrompt: false);
      final controller = PwaInstallController(bridge: bridge, prefs: prefs);
      addTearDown(controller.dispose);

      var notified = 0;
      controller.addListener(() => notified++);

      bridge.canPrompt = true;
      bridge.emitChange();
      await Future<void>.delayed(Duration.zero);

      expect(notified, 1);
      expect(controller.canPromptNatively, isTrue);
    });

    test('persists and resets banner dismissal in SharedPreferences', () async {
      final bridge = _FakePwaBridge();
      final controller = PwaInstallController(bridge: bridge, prefs: prefs);
      addTearDown(controller.dispose);

      expect(controller.shouldShowBanner, isTrue);

      await controller.dismissBanner();
      expect(controller.isBannerDismissed, isTrue);
      expect(controller.shouldShowBanner, isFalse);
      expect(prefs.getBool(PwaInstallController.kDismissedKey), isTrue);

      final reloaded = PwaInstallController(
        bridge: _FakePwaBridge(),
        prefs: prefs,
      );
      addTearDown(reloaded.dispose);
      expect(reloaded.isBannerDismissed, isTrue);
      expect(reloaded.shouldShowBanner, isFalse);

      await reloaded.resetBannerDismissal();
      expect(reloaded.isBannerDismissed, isFalse);
      expect(reloaded.shouldShowBanner, isTrue);
    });

    test('parses platform hints including Firefox Android and Desktop', () {
      expect(parsePwaPlatformHint('ios'), PwaPlatformHint.ios);
      expect(parsePwaPlatformHint('macos-safari'), PwaPlatformHint.macosSafari);
      expect(
        parsePwaPlatformHint('firefox-android'),
        PwaPlatformHint.firefoxAndroid,
      );
      expect(
        parsePwaPlatformHint('firefox-desktop'),
        PwaPlatformHint.firefoxDesktop,
      );
      expect(parsePwaPlatformHint('unsupported'), PwaPlatformHint.unsupported);
      expect(parsePwaPlatformHint('standard'), PwaPlatformHint.standard);
      expect(parsePwaPlatformHint(null), PwaPlatformHint.standard);
    });

    test('Firefox desktop never invokes the native prompt', () async {
      final bridge = _FakePwaBridge(
        canPrompt: true,
        platformHint: PwaPlatformHint.firefoxDesktop,
      );
      final controller = PwaInstallController(
        bridge: bridge,
        prefs: prefs,
        os: TargetPlatform.linux,
      );
      addTearDown(controller.dispose);

      expect(controller.platformHint, PwaPlatformHint.firefoxDesktop);
      expect(controller.shouldShowBanner, isTrue);
    });

    test('resolvePwaPlatformHint refines the browser hint by system', () {
      PwaPlatformHint resolve(TargetPlatform os, PwaPlatformHint hint) =>
          resolvePwaPlatformHint(os: os, browserHint: hint);

      expect(
        resolve(TargetPlatform.android, PwaPlatformHint.standard),
        PwaPlatformHint.android,
      );
      expect(
        resolve(TargetPlatform.android, PwaPlatformHint.firefoxDesktop),
        PwaPlatformHint.firefoxAndroid,
      );
      expect(
        resolve(TargetPlatform.android, PwaPlatformHint.firefoxAndroid),
        PwaPlatformHint.firefoxAndroid,
      );
      expect(
        resolve(TargetPlatform.iOS, PwaPlatformHint.standard),
        PwaPlatformHint.ios,
      );
      expect(
        resolve(TargetPlatform.linux, PwaPlatformHint.firefoxDesktop),
        PwaPlatformHint.firefoxDesktop,
      );
      expect(
        resolve(TargetPlatform.macOS, PwaPlatformHint.macosSafari),
        PwaPlatformHint.macosSafari,
      );
      expect(
        resolve(TargetPlatform.windows, PwaPlatformHint.standard),
        PwaPlatformHint.standard,
      );
      expect(
        resolve(TargetPlatform.android, PwaPlatformHint.unsupported),
        PwaPlatformHint.unsupported,
      );
    });
  });

  group('PwaInstallBanner & PwaInstallSheet widgets', () {
    testWidgets('renders banner and triggers native install prompt on tap', (
      tester,
    ) async {
      final bridge = _FakePwaBridge(
        canPrompt: true,
        nextPromptResult: PwaPromptResult.accepted,
      );
      final controller = PwaInstallController(bridge: bridge, prefs: prefs);
      addTearDown(controller.dispose);

      await tester.runAsync(() async {
        await tester.pumpWidget(
          _wrapWithLocalization(PwaInstallBanner(controller: controller)),
        );
        await tester.pumpAndSettle();

        expect(find.text('Install LettMat'), findsOneWidget);
        expect(find.text('Install'), findsOneWidget);

        await tester.tap(find.text('Install'));
        await tester.pumpAndSettle();

        expect(bridge.promptCallCount, 1);
        expect(find.text('LettMat installed successfully.'), findsOneWidget);
        expect(find.text('Install LettMat'), findsNothing);
      });
    });

    testWidgets(
      'opens iOS guided installation sheet when native prompt is unavailable',
      (tester) async {
        final bridge = _FakePwaBridge(
          canPrompt: false,
          platformHint: PwaPlatformHint.ios,
        );
        final controller = PwaInstallController(
          bridge: bridge,
          prefs: prefs,
          os: TargetPlatform.iOS,
        );
        addTearDown(controller.dispose);

        await tester.runAsync(() async {
          await tester.pumpWidget(
            _wrapWithLocalization(PwaInstallBanner(controller: controller)),
          );
          await tester.pumpAndSettle();

          await tester.tap(find.text('Install'));
          await tester.pumpAndSettle();

          expect(
            find.text('Tap the Share button in your browser toolbar.'),
            findsOneWidget,
          );
          expect(
            find.text('Select "Add to Home Screen" and tap Add.'),
            findsOneWidget,
          );

          await tester.tap(
            find.descendant(
              of: find.byType(PwaInstallSheet),
              matching: find.byIcon(Icons.close),
            ),
          );
          await tester.pumpAndSettle();

          expect(
            find.text('Tap the Share button in your browser toolbar.'),
            findsNothing,
          );
        });
      },
    );

    testWidgets('shows Firefox Android installation instructions in sheet', (
      tester,
    ) async {
      final bridge = _FakePwaBridge(
        canPrompt: false,
        platformHint: PwaPlatformHint.firefoxAndroid,
      );
      final controller = PwaInstallController(
        bridge: bridge,
        prefs: prefs,
        os: TargetPlatform.android,
      );
      addTearDown(controller.dispose);

      await tester.runAsync(() async {
        await tester.pumpWidget(
          _wrapWithLocalization(PwaInstallBanner(controller: controller)),
        );
        await tester.pumpAndSettle();

        expect(find.text('Install LettMat'), findsOneWidget);
        await tester.tap(find.text('Install'));
        await tester.pumpAndSettle();

        expect(
          find.text('Tap the menu button (three dots) in Firefox.'),
          findsOneWidget,
        );
        expect(
          find.text('Choose "Install" or "Add to Home screen" and confirm.'),
          findsOneWidget,
        );
      });
    });

    testWidgets('Firefox desktop gets install steps instead of a notice', (
      tester,
    ) async {
      final bridge = _FakePwaBridge(
        canPrompt: false,
        platformHint: PwaPlatformHint.firefoxDesktop,
      );
      final controller = PwaInstallController(
        bridge: bridge,
        prefs: prefs,
        os: TargetPlatform.linux,
      );
      addTearDown(controller.dispose);

      await tester.runAsync(() async {
        await tester.pumpWidget(
          _wrapWithLocalization(PwaInstallBanner(controller: controller)),
        );
        await tester.pumpAndSettle();

        expect(find.text('Install LettMat'), findsOneWidget);
        expect(find.text('Learn more'), findsNothing);

        await tester.tap(find.text('Install'));
        await tester.pumpAndSettle();

        expect(
          find.text(
            'Open the Firefox menu, or click the install icon in the address bar.',
          ),
          findsOneWidget,
        );
      });
    });

    testWidgets('Android gets the browser menu steps', (tester) async {
      final bridge = _FakePwaBridge(canPrompt: false);
      final controller = PwaInstallController(
        bridge: bridge,
        prefs: prefs,
        os: TargetPlatform.android,
      );
      addTearDown(controller.dispose);

      await tester.runAsync(() async {
        await tester.pumpWidget(
          _wrapWithLocalization(PwaInstallBanner(controller: controller)),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Install'));
        await tester.pumpAndSettle();

        expect(
          find.text('Tap the menu button (three dots) in your browser.'),
          findsOneWidget,
        );
      });
    });

    testWidgets('dismiss button hides the install banner', (tester) async {
      final bridge = _FakePwaBridge();
      final controller = PwaInstallController(bridge: bridge, prefs: prefs);
      addTearDown(controller.dispose);

      await tester.runAsync(() async {
        await tester.pumpWidget(
          _wrapWithLocalization(PwaInstallBanner(controller: controller)),
        );
        await tester.pumpAndSettle();

        expect(find.text('Install LettMat'), findsOneWidget);

        await tester.tap(find.byIcon(Icons.close));
        await tester.pumpAndSettle();

        expect(find.text('Install LettMat'), findsNothing);
        expect(controller.isBannerDismissed, isTrue);
      });
    });

    testWidgets(
      'automatically hides banner when app transitions to installed mode',
      (tester) async {
        final bridge = _FakePwaBridge(isInstalled: false);
        final controller = PwaInstallController(bridge: bridge, prefs: prefs);
        addTearDown(controller.dispose);

        await tester.runAsync(() async {
          await tester.pumpWidget(
            _wrapWithLocalization(PwaInstallBanner(controller: controller)),
          );
          await tester.pumpAndSettle();

          expect(find.text('Install LettMat'), findsOneWidget);

          bridge.isInstalled = true;
          bridge.emitChange();
          await Future<void>.delayed(Duration.zero);
          await tester.pumpAndSettle();

          expect(find.text('Install LettMat'), findsNothing);
          expect(controller.isBannerDismissed, isFalse);
        });
      },
    );
  });
}
