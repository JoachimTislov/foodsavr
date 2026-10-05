import 'package:flutter/services.dart' show rootBundle;

class LegalDocs {
  static const _privacyNoticePath = 'assets/legal/privacy_notice.md';
  static const _termsOfServicePath = 'assets/legal/terms_of_service.md';

  static Future<String> privacyNotice() =>
      rootBundle.loadString(_privacyNoticePath);

  static Future<String> termsOfService() =>
      rootBundle.loadString(_termsOfServicePath);
}
