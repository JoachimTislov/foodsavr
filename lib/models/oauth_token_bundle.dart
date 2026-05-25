class OAuthTokenBundle {
  const OAuthTokenBundle({
    required this.accessToken,
    this.refreshToken,
    this.idToken,
    this.accessTokenExpirationDateTime,
  });

  final String accessToken;
  final String? refreshToken;
  final String? idToken;
  final DateTime? accessTokenExpirationDateTime;
}
