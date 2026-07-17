import 'dart:io';
import 'package:integration_test/integration_test_driver_extended.dart';

Future<void> main() async {
  await integrationDriver(
    onScreenshot:
        (
          String screenshotName,
          List<int> screenshotBytes, [
          Map<String, Object?>? args,
        ]) async {
          final File image = File('$screenshotName.png');
          image.writeAsBytesSync(screenshotBytes);
          // Return false if the screenshot is invalid.
          return true;
        },
  );
}

// web: https://github.com/flutter/flutter/tree/main/packages/integration_test#web-1
