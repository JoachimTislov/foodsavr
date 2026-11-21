import 'package:web/web.dart' as web;

import 'app_check_settings.dart';

void prepareAppCheckStorage({required String? enterpriseSiteKey}) {
  for (final storage in [web.window.localStorage, web.window.sessionStorage]) {
    migrateAppCheckSettings(
      (key) => storage.getItem(key),
      (key) => storage.removeItem(key),
      enterpriseSiteKey: enterpriseSiteKey,
    );
  }
}
