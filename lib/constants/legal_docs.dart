import 'package:flutter/services.dart' show rootBundle;

import '../utils/config.dart';

enum LegalDoc { privacy, terms }

class LegalDocs {
  static const contactEmail = 'dev.joachim.tislov@gmail.com';

  static const _productionDocuments = {
    (LegalDoc.privacy, 'en'): 'privacy_notice.md',
    (LegalDoc.privacy, 'nb'): 'privacy_notice_nb.md',
    (LegalDoc.terms, 'en'): 'terms_of_service.md',
    (LegalDoc.terms, 'nb'): 'terms_of_service_nb.md',
  };
  static const _testDocuments = {
    LegalDoc.privacy: 'tester_privacy',
    LegalDoc.terms: 'tester_terms',
  };

  /// Returns the asset path under `assets/legal/` for [document] and
  /// [languageCode] in the given [environment] (or the configured runtime
  /// environment when omitted).
  static String assetPathFor(
    LegalDoc document,
    String languageCode, {
    String? environment,
  }) {
    final configured = Config.legalEnvironment;
    final resolvedEnvironment =
        environment ?? (configured.isEmpty ? Config.environment : configured);
    final locale = languageCode == 'nb' ? 'nb' : 'en';
    final asset = switch (resolvedEnvironment) {
      'development' ||
      'test' ||
      'staging' => '${_testDocuments[document]}_$locale.txt',
      'production' => _productionDocuments[(document, locale)]!,
      _ => throw StateError(
        'Unsupported legal environment: $resolvedEnvironment',
      ),
    };
    return 'assets/legal/$asset';
  }

  static Future<String> load(
    LegalDoc document,
    String languageCode, {
    String? environment,
  }) {
    return rootBundle.loadString(
      assetPathFor(document, languageCode, environment: environment),
    );
  }
}
