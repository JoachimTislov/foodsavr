import 'dart:convert';
import 'dart:io';
import 'dart:math';

// Note: Requires the 'crypto' package. Run:
// cd /home/joachim/projects/foodsavr/default
// dart pub add crypto
import 'package:crypto/crypto.dart';

/// A pure OAuth 2.0 PKCE CLI Flow for Trumf.
///
/// Usage:
///   1. dart pub add crypto (in the default folder)
///   2. dart run tool/trumf_auth_test.dart
///
/// This script:
///   1. Generates a PKCE Verifier and Challenge.
///   2. Constructs the `id.trumf.no` Authorization URL.
///   3. Asks you to log in via your browser.
///   4. Takes the redirected URL and extracts the `code`.
///   5. Exchanges the `code` for the Access and Refresh tokens.

const String clientId = 'trumf';
const String redirectUri =
    'https://www.trumf.no/api/auth/callback/trumf-personal';
const String authEndpoint = 'https://id.trumf.no/connect/authorize';
const String tokenEndpoint = 'https://id.trumf.no/connect/token';

void main() async {
  print('--- Trumf OAuth 2.0 PKCE Flow ---');

  // 1. Generate PKCE values & State
  final String codeVerifier = _generateCodeVerifier();
  final String codeChallenge = _generateCodeChallenge(codeVerifier);
  final String stateString = _generateCodeVerifier().substring(
    0,
    16,
  ); // Random string for state

  // 2. Construct the Authorization URL
  final Uri authUrl = Uri.parse(authEndpoint).replace(
    queryParameters: {
      'client_id': clientId,
      'redirect_uri': redirectUri,
      'response_type': 'code',
      'scope':
          'api.rest api.sylinder api.trumfid api.trumfid.biometri.administration api.trumfid.biometri.administration.read http://id.trumf.no/scopes/medlem offline_access openid profile',
      'code_challenge': codeChallenge,
      'code_challenge_method': 'S256',
      'state': stateString,
    },
  );

  print(
    '\nStep 1: Open the following URL in your browser to log in to Trumf:\n',
  );
  print(authUrl.toString());
  print('\n---------------------------------------------------------');

  // 3. Prompt user for the redirect URL
  print('\nStep 2: After logging in, you will be redirected back.');
  print('Look at your browser address bar. It should look like:');
  print('https://www.trumf.no/api/auth/callback/trumf-personal?code=XYZ123...');
  stdout.write('\nPaste the FULL redirected URL here: ');
  final String? inputUrl = stdin.readLineSync()?.trim();

  if (inputUrl == null || inputUrl.isEmpty) {
    print('Error: No URL provided.');
    exit(1);
  }

  // 4. Extract the code
  final Uri parsedRedirect = Uri.parse(inputUrl);
  final String? authCode = parsedRedirect.queryParameters['code'];

  if (authCode == null) {
    print('Error: Could not find the "code" parameter in the provided URL.');
    print('Parsed Query Parameters: ${parsedRedirect.queryParameters}');
    exit(1);
  }

  print('\nExtracted Auth Code: $authCode');
  print('Step 3: Exchanging Code for Tokens...');

  // 5. Exchange code for token
  await _exchangeCodeForTokens(authCode, codeVerifier);
}

Future<void> _exchangeCodeForTokens(String code, String codeVerifier) async {
  final client = HttpClient();
  try {
    final request = await client.postUrl(Uri.parse(tokenEndpoint));

    // OIDC /token endpoint expects form-urlencoded body
    final Map<String, String> body = {
      'grant_type': 'authorization_code',
      'client_id': clientId,
      'redirect_uri': redirectUri,
      'code': code,
      'code_verifier': codeVerifier,
    };

    final String encodedBody = body.entries
        .map(
          (e) =>
              '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}',
        )
        .join('&');

    request.headers.contentType = ContentType(
      'application',
      'x-www-form-urlencoded',
      charset: 'utf-8',
    );
    request.headers.set('User-Agent', 'FoodSavr-Integration-Tool/1.0');
    request.write(encodedBody);

    final response = await request.close();
    final responseBody = await response.transform(utf8.decoder).join();

    if (response.statusCode == 200) {
      final data = jsonDecode(responseBody);
      print('\n✅ SUCCESS! Tokens Retrieved:');
      print('---------------------------------------------------------');
      print('Access Token (Bearer): \n${data['access_token']}\n');

      if (data.containsKey('refresh_token')) {
        print('Refresh Token: \n${data['refresh_token']}\n');
      }

      print('Expires In: ${data['expires_in']} seconds');
      print('Scopes: ${data['scope']}');
      print('---------------------------------------------------------');

      print(
        '\nYou can now use this Access Token to fetch Trumf receipts using the previous script:',
      );
      print('export TRUMF_TOKEN="${data['access_token']}"');
      print('dart run tool/trumf_integration.dart');
    } else {
      print('\n❌ Token Exchange Failed!');
      print('Status Code: ${response.statusCode}');
      print('Response: $responseBody');
    }
  } catch (e) {
    print('HTTP Request Error: $e');
  } finally {
    client.close();
  }
}

/// Generates a random cryptographic string (43-128 chars) as defined in RFC 7636.
String _generateCodeVerifier() {
  final Random random = Random.secure();
  final List<int> bytes = List<int>.generate(64, (i) => random.nextInt(256));
  return base64UrlEncode(bytes).replaceAll('=', '');
}

/// Hashes the verifier with SHA-256 and base64url-encodes it.
String _generateCodeChallenge(String verifier) {
  final List<int> bytes = utf8.encode(verifier);
  final Digest digest = sha256.convert(bytes);
  return base64UrlEncode(digest.bytes).replaceAll('=', '');
}
