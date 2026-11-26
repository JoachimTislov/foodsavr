import 'dart:ui';

/// Locales the app ships translations for; the first is the fallback.
const enLocale = Locale('en');
const nbLocale = Locale('nb');
const supportedAppLocales = [enLocale, nbLocale];

/// The locale to start in when the user has not chosen one yet.
///
/// Matches the device language; Norwegian (`no`, `nn`) maps to Bokmål, and
/// unsupported languages fall back to English.
Locale startLocaleFor(Locale device) {
  return switch (device.languageCode) {
    'nb' || 'no' || 'nn' => nbLocale,
    _ => enLocale,
  };
}
