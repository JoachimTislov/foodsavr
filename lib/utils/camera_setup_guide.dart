import 'package:easy_localization/easy_localization.dart';

import 'pwa_install/pwa_bridge_types.dart';

/// The translated steps that re-enable a blocked camera, in the
/// order the user follows them. [hint] combines the device's operating system
/// with the browser family; [PwaPlatformHint.unsupported] means a native app.
List<String> cameraSetupSteps(PwaPlatformHint hint) => switch (hint) {
  PwaPlatformHint.unsupported => [
    'camera.guide.native.step1'.tr(),
    'camera.guide.native.step2'.tr(),
  ],
  PwaPlatformHint.firefoxAndroid => [
    'camera.guide.firefoxAndroid.step1'.tr(),
    'camera.guide.firefoxAndroid.step2'.tr(),
  ],
  PwaPlatformHint.android => [
    'camera.guide.androidChrome.step1'.tr(),
    'camera.guide.androidChrome.step2'.tr(),
  ],
  PwaPlatformHint.ios => [
    'camera.guide.ios.step1'.tr(),
    'camera.guide.ios.step2'.tr(),
  ],
  PwaPlatformHint.macosSafari => ['camera.guide.macosSafari.step1'.tr()],
  PwaPlatformHint.firefoxDesktop => ['camera.guide.firefoxDesktop.step1'.tr()],
  PwaPlatformHint.standard => ['camera.guide.desktop.step1'.tr()],
};
