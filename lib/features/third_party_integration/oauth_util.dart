import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:foodsavr/features/third_party_integration/models/provider_model.dart';

class OAuthUtil {
  final Provider _provider;

  OAuthUtil(this._provider);

  final String _codeVerifier = _generateCodeVerifier();
  final String _state = _generateCodeVerifier();

  String? get userInfoEndpoint => env('USER_INFO');
  String? get discoveryUrl => env('DISCOVERY_URL');
  // Map<String, String> get additionalParameters => load('ADDITIONAL_PARAMETERS').split(pattern);

  String _key(String key) {
    return '${_provider.name.toUpperCase()}_$key';
  }

  String env(String key) => dotenv.get(_key(key));
  String? maybeEnv(String key) => dotenv.maybeGet(_key(key));

  Map<String, String> get baseParams => {
    'client_id': env('CLIENT_ID'),
    'redirect_uri': env('REDIRECT_URL'),
  };

  /// authUri creates uri to start oauth flow
  // throw AssertionError if env variable SCOPES or AUTHORIZATION is not present
  Uri authUri() {
    final params = {
      ...baseParams,
      'response_type': 'code',
      'code_challenge_method': 'S256',
      'code_challenge': _generateCodeChallenge(_codeVerifier),
      'scope': env('SCOPES'),
      'state': _state,
      'audience': maybeEnv('AUDIENCE'),
    };
    return Uri.parse(env('AUTHORIZATION_URL')).replace(queryParameters: params);
  }

  bool matchesRedirect(Uri uri) {
    final redirect = Uri.parse(env('REDIRECT_URL'));
    return uri.scheme == redirect.scheme &&
        uri.authority == redirect.authority &&
        uri.path == redirect.path;
  }

  String authorizationCode(Uri uri) {
    final states = uri.queryParametersAll['state'];
    final codes = uri.queryParametersAll['code'];
    if (!matchesRedirect(uri) ||
        states == null ||
        states.length != 1 ||
        states.single != _state ||
        codes == null ||
        codes.length != 1 ||
        codes.single.isEmpty ||
        uri.queryParameters.containsKey('error')) {
      throw const OAuthAuthorizationException();
    }
    return codes.single;
  }

  Map<String, String> tokenBody(String code) {
    return {
      ...baseParams,
      'grant_type': 'authorization_code',
      'code': code,
      'code_verifier': _codeVerifier,
    };
  }

  static String _generateCodeVerifier() {
    final random = Random.secure();
    final values = List<int>.generate(32, (i) => random.nextInt(256));
    // Base64-url encode and remove padding '='
    return base64UrlEncode(values).replaceAll('=', '');
  }

  /// Hashes the verifier using SHA-256 and Base64-URL encodes it
  static String _generateCodeChallenge(String verifier) {
    final bytes = utf8.encode(verifier);
    final digest = sha256.convert(bytes);
    return base64UrlEncode(digest.bytes).replaceAll('=', '');
  }
}

class OAuthAuthorizationException implements Exception {
  const OAuthAuthorizationException();
}

class OAuthAuthorizationCancelled implements Exception {
  const OAuthAuthorizationCancelled();
}
