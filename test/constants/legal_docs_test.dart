import 'package:flutter_test/flutter_test.dart';
import 'package:foodsavr/constants/legal_docs.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LegalDocs', () {
    test('resolves localized asset paths per environment', () {
      expect(
        LegalDocs.assetPathFor(LegalDoc.privacy, 'en', environment: 'test'),
        'assets/legal/tester_privacy_en.txt',
      );
      expect(
        LegalDocs.assetPathFor(LegalDoc.privacy, 'nb', environment: 'staging'),
        'assets/legal/tester_privacy_nb.txt',
      );
      expect(
        LegalDocs.assetPathFor(
          LegalDoc.terms,
          'en',
          environment: 'development',
        ),
        'assets/legal/tester_terms_en.txt',
      );
      expect(
        LegalDocs.assetPathFor(LegalDoc.terms, 'nb', environment: 'test'),
        'assets/legal/tester_terms_nb.txt',
      );
      expect(
        LegalDocs.assetPathFor(
          LegalDoc.privacy,
          'en',
          environment: 'production',
        ),
        'assets/legal/privacy_notice.md',
      );
      expect(
        LegalDocs.assetPathFor(
          LegalDoc.privacy,
          'nb',
          environment: 'production',
        ),
        'assets/legal/privacy_notice_nb.md',
      );
      expect(
        LegalDocs.assetPathFor(LegalDoc.terms, 'en', environment: 'production'),
        'assets/legal/terms_of_service.md',
      );
      expect(
        LegalDocs.assetPathFor(LegalDoc.terms, 'nb', environment: 'production'),
        'assets/legal/terms_of_service_nb.md',
      );
      expect(
        LegalDocs.assetPathFor(LegalDoc.terms, 'fr', environment: 'production'),
        'assets/legal/terms_of_service.md',
      );
      expect(
        () => LegalDocs.assetPathFor(
          LegalDoc.privacy,
          'en',
          environment: 'unknown',
        ),
        throwsStateError,
      );
    });

    test(
      'all legal assets are finalized with LettMat branding and real contact email',
      () async {
        for (final env in const ['development', 'production']) {
          for (final locale in const ['en', 'nb']) {
            for (final doc in LegalDoc.values) {
              final content = await LegalDocs.load(
                doc,
                locale,
                environment: env,
              );
              expect(
                content.trim(),
                isNotEmpty,
                reason: '$env/$locale/$doc should not be empty',
              );
              expect(
                content,
                contains(LegalDocs.contactEmail),
                reason: '$env/$locale/$doc must include real contact email',
              );
              expect(
                content,
                contains('LettMat'),
                reason: '$env/$locale/$doc must mention LettMat',
              );
              expect(
                content,
                isNot(contains('todo@gmail.com')),
                reason: '$env/$locale/$doc must not contain placeholder email',
              );
              expect(
                content,
                isNot(contains('placeholder.invalid')),
                reason: '$env/$locale/$doc must not contain placeholder domain',
              );
              expect(
                content,
                isNot(contains('Draft for human review')),
                reason: '$env/$locale/$doc must not contain draft banner',
              );
              expect(
                content,
                isNot(contains('Utkast til manuell gjennomgang')),
                reason: '$env/$locale/$doc must not contain draft banner',
              );
              expect(
                content,
                isNot(contains('TODO')),
                reason: '$env/$locale/$doc must not contain TODO markers',
              );
            }
          }
        }
      },
    );
  });
}
