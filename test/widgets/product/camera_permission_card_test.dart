import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foodsavr/services/camera_permission_service.dart';
import 'package:foodsavr/utils/pwa_install/pwa_bridge_types.dart';
import 'package:foodsavr/widgets/product/camera_permission_card.dart';

import '../../support/localized_app.dart';

void main() {
  setUpAll(setUpLocalizedApp);

  const titles = {
    CameraAccessStatus.prompt: ('Camera access', 'Kameratilgang'),
    CameraAccessStatus.disabledInSettings: (
      'Camera access is off',
      'Kameratilgang er av',
    ),
    CameraAccessStatus.denied: (
      'Camera permission denied',
      'Kameratilgang avslått',
    ),
    CameraAccessStatus.noCamera: ('No camera found', 'Fant ikke noe kamera'),
    CameraAccessStatus.insecureContext: (
      'Secure connection required',
      'Sikker tilkobling kreves',
    ),
    CameraAccessStatus.inUse: (
      'The camera could not start',
      'Kameraet kunne ikke starte',
    ),
    CameraAccessStatus.unsupported: (
      'Camera scanning is not available',
      'Kameraskanning er ikke tilgjengelig',
    ),
  };

  for (final MapEntry(key: status, value: (en, nb)) in titles.entries) {
    for (final (language, title) in [('en', en), ('nb', nb)]) {
      testWidgets('${status.name} is explained in $language with actions', (
        tester,
      ) async {
        var retries = 0;
        var enables = 0;
        var fallbacks = 0;
        await pumpLocalized(
          tester,
          Scaffold(
            body: CameraPermissionCard(
              status: status,
              onRetry: () => retries++,
              onEnable: () => enables++,
              onFallback: () => fallbacks++,
              fallbackLabel: 'manual',
            ),
          ),
          language: language,
        );

        expect(find.text(title), findsOneWidget);
        // No untranslated key shows.
        expect(find.textContaining(RegExp(r'camera\.[a-z]')), findsNothing);

        final retryLabel = status == CameraAccessStatus.prompt
            ? (language == 'en' ? 'Allow camera' : 'Tillat kamera')
            : 'common.tryAgain'.tr();
        final enableLabel = language == 'en'
            ? 'Enable camera'
            : 'Slå på kamera';

        switch (status) {
          case CameraAccessStatus.unsupported ||
              CameraAccessStatus.insecureContext:
            expect(find.text(retryLabel), findsNothing);
            expect(find.text(enableLabel), findsNothing);
            expect(find.widgetWithText(FilledButton, 'manual'), findsOneWidget);
            await tester.tap(find.widgetWithText(FilledButton, 'manual'));
            expect((retries, enables, fallbacks), (0, 0, 1));
          case CameraAccessStatus.noCamera:
            expect(find.widgetWithText(FilledButton, 'manual'), findsOneWidget);
            expect(
              find.widgetWithText(OutlinedButton, retryLabel),
              findsOneWidget,
            );
            expect(find.text(enableLabel), findsNothing);
            await tester.tap(find.widgetWithText(OutlinedButton, retryLabel));
            await tester.tap(find.widgetWithText(FilledButton, 'manual'));
            expect((retries, enables, fallbacks), (1, 0, 1));
          case CameraAccessStatus.disabledInSettings:
            expect(find.text(retryLabel), findsNothing);
            expect(
              find.widgetWithText(FilledButton, enableLabel),
              findsOneWidget,
            );
            expect(find.widgetWithText(TextButton, 'manual'), findsOneWidget);
            await tester.tap(find.widgetWithText(FilledButton, enableLabel));
            await tester.tap(find.widgetWithText(TextButton, 'manual'));
            expect((retries, enables, fallbacks), (0, 1, 1));
          case CameraAccessStatus.prompt ||
              CameraAccessStatus.granted ||
              CameraAccessStatus.denied ||
              CameraAccessStatus.inUse:
            expect(
              find.widgetWithText(FilledButton, retryLabel),
              findsOneWidget,
            );
            expect(find.widgetWithText(TextButton, 'manual'), findsOneWidget);
            expect(find.text(enableLabel), findsNothing);
            await tester.tap(find.widgetWithText(FilledButton, retryLabel));
            await tester.tap(find.widgetWithText(TextButton, 'manual'));
            expect((retries, enables, fallbacks), (1, 0, 1));
        }
      });
    }
  }

  testWidgets(
    'unsupported and insecureContext omit actions when no fallback exists',
    (tester) async {
      for (final status in [
        CameraAccessStatus.unsupported,
        CameraAccessStatus.insecureContext,
      ]) {
        await pumpLocalized(
          tester,
          Scaffold(
            body: CameraPermissionCard(status: status, onRetry: () {}),
          ),
        );

        expect(find.byType(FilledButton), findsNothing);
        expect(find.byType(OutlinedButton), findsNothing);
        expect(find.byType(TextButton), findsNothing);
      }
    },
  );

  testWidgets('a denied camera lists the steps for the browser and system', (
    tester,
  ) async {
    await pumpLocalized(
      tester,
      Scaffold(
        body: CameraPermissionCard(
          status: CameraAccessStatus.denied,
          onRetry: () {},
          platformHint: PwaPlatformHint.firefoxAndroid,
        ),
      ),
    );

    expect(find.text('How to allow the camera'), findsOneWidget);
    expect(find.textContaining('1. In Firefox'), findsOneWidget);
    expect(find.textContaining('2. Open Android Settings'), findsOneWidget);
  });

  testWidgets('other states show no setup steps', (tester) async {
    await pumpLocalized(
      tester,
      Scaffold(
        body: CameraPermissionCard(
          status: CameraAccessStatus.noCamera,
          onRetry: () {},
          platformHint: PwaPlatformHint.firefoxAndroid,
        ),
      ),
    );

    expect(find.text('How to allow the camera'), findsNothing);
  });
}
