class PublicRoutes {
  // Canonical URL-backed modal routes.
  static const privacy = '/legal/privacy';
  static const terms = '/legal/terms';
  static const deleteAccount = '/account/delete';

  // Legacy aliases kept for external links (for example Meta/Facebook policy URLs).
  static const legacyPrivacy = '/privacy';
  static const legacyTerms = '/terms';
  static const legacyDeleteAccount = '/delete-account';

  static const deleteAccountSignIn = '/auth?returnTo=$deleteAccount';
  static const webAccess = '/access';

  static const Set<String> _privacyPaths = {privacy, legacyPrivacy};
  static const Set<String> _termsPaths = {terms, legacyTerms};
  static const Set<String> _deleteAccountPaths = {
    deleteAccount,
    legacyDeleteAccount,
  };

  static bool isPublic(String path) => canonicalize(path) != null;

  static bool isDeletionSignIn(Uri uri) =>
      uri.path == '/auth' &&
      canonicalize(uri.queryParameters['returnTo'] ?? '') == deleteAccount;

  /// Returns the canonical path for a public legal or account-deletion route
  /// (including legacy aliases and trailing slashes), or `null` if [path] does
  /// not match any public route.
  static String? canonicalize(String path) {
    final normalized = _normalizePath(path);
    if (_privacyPaths.contains(normalized)) return privacy;
    if (_termsPaths.contains(normalized)) return terms;
    if (_deleteAccountPaths.contains(normalized)) return deleteAccount;
    return null;
  }

  /// Resolves hash-fragment URLs such as `/#/legal/terms`, `/#/privacy`, or
  /// `/#/account/delete` to their canonical path, preserving query parameters
  /// when present. Returns `null` when [uri] has no matching public hash route.
  static String? resolveHashRoute(Uri? uri) {
    if (uri == null || uri.fragment.isEmpty) return null;
    final rawFragment = uri.fragment.trim();
    if (rawFragment.isEmpty || rawFragment.contains('\\')) return null;
    final fragmentUri = Uri.tryParse(rawFragment);
    if (fragmentUri == null ||
        fragmentUri.hasScheme ||
        fragmentUri.hasAuthority) {
      return null;
    }
    final canonical = canonicalize(fragmentUri.path);
    if (canonical == null) return null;
    if (fragmentUri.hasQuery) {
      return Uri(path: canonical, query: fragmentUri.query).toString();
    }
    return canonical;
  }

  static String _normalizePath(String raw) {
    var path = raw.trim();
    if (path.isEmpty) return '';
    if (!path.startsWith('/')) path = '/$path';
    while (path.length > 1 && path.endsWith('/')) {
      path = path.substring(0, path.length - 1);
    }
    return path;
  }
}
