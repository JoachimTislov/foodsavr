import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foodsavr/services/camera_permission_service.dart';
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

        final retry = status == CameraAccessStatus.prompt
            ? (language == 'en' ? 'Allow camera' : 'Tillat kamera')
            : 'common.tryAgain'.tr();
        await tester.tap(find.text(retry));
        await tester.tap(find.text('manual'));
        expect((retries, fallbacks), (1, 1));

        final enable = find.text(
          language == 'en' ? 'Enable camera' : 'Slå på kamera',
        );
        if (status == CameraAccessStatus.disabledInSettings) {
          await tester.tap(enable);
          expect(enables, 1);
        } else {
          expect(enable, findsNothing);
        }
      });
    }
  }
}
