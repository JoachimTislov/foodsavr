import 'package:flutter/services.dart' show rootBundle;

import '../utils/config.dart';

enum LegalDoc { privacy, terms }

class LegalDocs {
  static const _legacyProduction = {
    LegalDoc.privacy: 'privacy_notice.md',
    LegalDoc.terms: 'terms_of_service.md',
  };
  static const _testDocuments = {
    LegalDoc.privacy: 'tester_privacy',
    LegalDoc.terms: 'tester_terms',
  };

  static Future<String> load(LegalDoc document, String languageCode) {
    final configured = Config.legalEnvironment;
    final environment = configured.isEmpty ? Config.environment : configured;
    final locale = languageCode == 'nb' ? 'nb' : 'en';
    final asset = switch (environment) {
      'development' ||
      'test' ||
      'staging' => '${_testDocuments[document]}_$locale.txt',
      'production' => _legacyProduction[document]!,
      _ => throw StateError('Unsupported legal environment: $environment'),
    };
    return rootBundle.loadString('assets/legal/$asset');
  }
}
