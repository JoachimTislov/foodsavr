import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foodsavr/utils/app_locales.dart';

void main() {
  test('starts Norwegian devices in Bokmål', () {
    expect(startLocaleFor(const Locale('nb', 'NO')), nbLocale);
    expect(startLocaleFor(const Locale('no')), nbLocale);
    expect(startLocaleFor(const Locale('nn')), nbLocale);
  });

  test('starts other devices in English', () {
    expect(startLocaleFor(const Locale('en', 'US')), enLocale);
    expect(startLocaleFor(const Locale('de')), enLocale);
  });
}
