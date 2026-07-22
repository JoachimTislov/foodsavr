import 'package:freezed_annotation/freezed_annotation.dart';

part 'oauth_token_model.freezed.dart';
part 'oauth_token_model.g.dart';

@freezed
abstract class OAuthToken with _$OAuthToken {
  const OAuthToken._();

  const factory OAuthToken({
    required String? access,
    required String? refresh,
    required String? id,
    required String? exp,
  }) = _OAuthToken;

  factory OAuthToken.fromJson(Map<String, dynamic> json) =>
      _$OAuthTokenFromJson(json);
}
