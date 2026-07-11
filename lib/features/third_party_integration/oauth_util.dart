import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:foodsavr/features/third_party_integration/models/m_provider.dart';

class OAuthUtil {
  final Provider _provider;

  OAuthUtil(this._provider);

  static final String codeVerifier = _generateCodeVerifier();
  static final String codeChallenge = _generateCodeChallenge(codeVerifier);

  String? get userInfoEndpoint => env('USER_INFO');
  String? get discoveryUrl => env('DISCOVERY_URL');
  // Map<String, String> get additionalParameters => load('ADDITIONAL_PARAMETERS').split(pattern);
  String get randomValue => _generateCodeVerifier().substring(0, 16);

  String _key(String key) {
    return '${_provider.name.toUpperCase()}_$key';
  }

  String env(String key) => dotenv.get(_key(key));
  String? _maybeEnv(String key) => dotenv.maybeGet(_key(key));

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
      'code_challenge': codeChallenge,
      'scope': env('SCOPES'),
      'state': randomValue,
      'audience': _maybeEnv('AUDIENCE'),
    };
    return Uri.parse(env('AUTHORIZATION_URL')).replace(queryParameters: params);
  }

  Map<String, String> tokenBody(String code) {
    return {
      ...baseParams,
      'grant_type': 'authorization_code',
      'code': code,
      'code_verifier': codeVerifier,
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
