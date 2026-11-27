import 'package:flutter_test/flutter_test.dart';
import 'package:foodsavr/constants/public_routes.dart';

void main() {
  group('PublicRoutes', () {
    test(
      'canonicalizes canonical routes, legacy aliases, and trailing slashes',
      () {
        expect(
          PublicRoutes.canonicalize('/legal/privacy'),
          PublicRoutes.privacy,
        );
        expect(PublicRoutes.canonicalize('/privacy'), PublicRoutes.privacy);
        expect(PublicRoutes.canonicalize('/privacy/'), PublicRoutes.privacy);
        expect(PublicRoutes.canonicalize('/legal/terms'), PublicRoutes.terms);
        expect(PublicRoutes.canonicalize('/terms'), PublicRoutes.terms);
        expect(PublicRoutes.canonicalize('/legal/terms/'), PublicRoutes.terms);
        expect(
          PublicRoutes.canonicalize('/account/delete'),
          PublicRoutes.deleteAccount,
        );
        expect(
          PublicRoutes.canonicalize('/delete-account'),
          PublicRoutes.deleteAccount,
        );
        expect(
          PublicRoutes.canonicalize('/delete-account/'),
          PublicRoutes.deleteAccount,
        );
        expect(PublicRoutes.canonicalize('/dashboard'), isNull);
        expect(PublicRoutes.canonicalize('/settings'), isNull);
        expect(PublicRoutes.canonicalize('/'), isNull);
      },
    );

    test('isPublic matches all canonical and legacy public paths', () {
      for (final path in const [
        '/legal/privacy',
        '/legal/terms',
        '/account/delete',
        '/privacy',
        '/terms',
        '/delete-account',
      ]) {
        expect(PublicRoutes.isPublic(path), isTrue, reason: path);
      }
      for (final path in const ['/', '/auth', '/dashboard', '/settings']) {
        expect(PublicRoutes.isPublic(path), isFalse, reason: path);
      }
    });

    test('isDeletionSignIn accepts canonical and legacy returnTo values', () {
      expect(
        PublicRoutes.isDeletionSignIn(
          Uri.parse('/auth?returnTo=/account/delete'),
        ),
        isTrue,
      );
      expect(
        PublicRoutes.isDeletionSignIn(
          Uri.parse('/auth?returnTo=/delete-account'),
        ),
        isTrue,
      );
      expect(
        PublicRoutes.isDeletionSignIn(Uri.parse('/auth?mode=login')),
        isFalse,
      );
      expect(
        PublicRoutes.isDeletionSignIn(Uri.parse('/auth?returnTo=/settings')),
        isFalse,
      );
    });

    test(
      'resolveHashRoute resolves # fragments for canonical and legacy URLs',
      () {
        expect(
          PublicRoutes.resolveHashRoute(
            Uri.parse('https://lettmat.app/#/legal/terms'),
          ),
          '/legal/terms',
        );
        expect(
          PublicRoutes.resolveHashRoute(
            Uri.parse('https://lettmat.app/#/legal/privacy'),
          ),
          '/legal/privacy',
        );
        expect(
          PublicRoutes.resolveHashRoute(
            Uri.parse('https://lettmat.app/#/account/delete'),
          ),
          '/account/delete',
        );
        expect(
          PublicRoutes.resolveHashRoute(
            Uri.parse('https://lettmat.app/#/terms'),
          ),
          '/legal/terms',
        );
        expect(
          PublicRoutes.resolveHashRoute(
            Uri.parse('https://lettmat.app/#/privacy'),
          ),
          '/legal/privacy',
        );
        expect(
          PublicRoutes.resolveHashRoute(
            Uri.parse('https://lettmat.app/#/delete-account'),
          ),
          '/account/delete',
        );
        expect(
          PublicRoutes.resolveHashRoute(Uri.parse('/#legal/terms/')),
          '/legal/terms',
        );
        expect(
          PublicRoutes.resolveHashRoute(Uri.parse('/#/legal/terms?lang=nb')),
          '/legal/terms?lang=nb',
        );
      },
    );

    test('resolveHashRoute ignores non-public and unsafe hash fragments', () {
      expect(PublicRoutes.resolveHashRoute(null), isNull);
      expect(
        PublicRoutes.resolveHashRoute(Uri.parse('https://lettmat.app/')),
        isNull,
      );
      expect(
        PublicRoutes.resolveHashRoute(
          Uri.parse('https://lettmat.app/#features'),
        ),
        isNull,
      );
      expect(
        PublicRoutes.resolveHashRoute(
          Uri.parse('https://lettmat.app/#access_token=abc123'),
        ),
        isNull,
      );
      expect(
        PublicRoutes.resolveHashRoute(
          Uri.parse('https://lettmat.app/#https://evil.example/terms'),
        ),
        isNull,
      );
    });
  });
}
