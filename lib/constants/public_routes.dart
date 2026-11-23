class PublicRoutes {
  static const privacy = '/privacy';
  static const terms = '/terms';
  static const deleteAccount = '/delete-account';
  static const deleteAccountSignIn = '/auth?returnTo=$deleteAccount';
  static const webAccess = '/access';

  static bool isPublic(String path) =>
      path == privacy || path == terms || path == deleteAccount;

  static bool isDeletionSignIn(Uri uri) =>
      uri.path == '/auth' && uri.queryParameters['returnTo'] == deleteAccount;
}
