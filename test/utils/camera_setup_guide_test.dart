import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:foodsavr/utils/camera_setup_guide.dart';
import 'package:foodsavr/utils/pwa_install/pwa_bridge_types.dart';

void main() {
  test('each system and browser gets its own steps', () {
    expect(cameraSetupSteps(PwaPlatformHint.firefoxAndroid), [
      'camera.guide.firefoxAndroid.step1',
      'camera.guide.firefoxAndroid.step2',
    ]);
    expect(cameraSetupSteps(PwaPlatformHint.android), [
      'camera.guide.androidChrome.step1',
      'camera.guide.androidChrome.step2',
    ]);
    expect(cameraSetupSteps(PwaPlatformHint.ios), [
      'camera.guide.ios.step1',
      'camera.guide.ios.step2',
    ]);
    expect(cameraSetupSteps(PwaPlatformHint.unsupported), [
      'camera.guide.native.step1',
      'camera.guide.native.step2',
    ]);
    expect(cameraSetupSteps(PwaPlatformHint.macosSafari), [
      'camera.guide.macosSafari.step1',
    ]);
    expect(cameraSetupSteps(PwaPlatformHint.firefoxDesktop), [
      'camera.guide.firefoxDesktop.step1',
    ]);
    expect(cameraSetupSteps(PwaPlatformHint.standard), [
      'camera.guide.desktop.step1',
    ]);
  });

  test('every step is translated in both languages', () {
    for (final language in ['en', 'nb']) {
      final json =
          jsonDecode(
                File('assets/translations/$language.json').readAsStringSync(),
              )
              as Map<String, dynamic>;
      for (final hint in PwaPlatformHint.values) {
        for (final key in cameraSetupSteps(hint)) {
          Object? node = json;
          for (final part in key.split('.')) {
            node = (node as Map<String, dynamic>)[part];
          }
          expect(node, isA<String>(), reason: '$language $key');
        }
      }
    }
  });
}
