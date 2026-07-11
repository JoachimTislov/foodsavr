class OAuthToken {
  final String? access;
  final String? refresh;
  final String? id;
  final String? exp;

  OAuthToken({
    required this.access,
    required this.refresh,
    required this.id,
    required this.exp,
  });
}
