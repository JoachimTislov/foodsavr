import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

class PKCEUtils {
  /// Generates a secure random code verifier
  static String generateCodeVerifier() {
    final random = Random.secure();
    final values = List<int>.generate(32, (i) => random.nextInt(256));
    // Base64-url encode and remove padding '='
    return base64UrlEncode(values).replaceAll('=', '');
  }

  /// Hashes the verifier using SHA-256 and Base64-URL encodes it
  static String generateCodeChallenge(String verifier) {
    final bytes = utf8.encode(verifier);
    final digest = sha256.convert(bytes);
    return base64UrlEncode(digest.bytes).replaceAll('=', '');
  }
}

void main() async {
  print('--- Coop Norway (Coop Medlem) Auth0 PKCE Flow Test ---');

  final clientId = 'RdbMJKxmpiqvlYR1DPAwrE1y5D3wJvXj';
  // final clientId = "7WrQEdeXwUudArpQVjmZEvrTgVs1WkRr";

  if (clientId == null || clientId.isEmpty) {
    print('A Client ID is required to authorize with Auth0. Exiting.');
    return;
  }

  stdout.write(
    'Enter the Auth0 Audience (e.g., https://api.coop.no). Leave blank to omit: ',
  );
  final audience = stdin.readLineSync()?.trim();

  // const redirectUri = 'no.coop.members://auth/callback';
  const redirectUri = 'https://minside.coop.no/api/auth/callback/auth0';

  // 1. Generate PKCE Secrets and State
  final codeVerifier = PKCEUtils.generateCodeVerifier();
  final codeChallenge = PKCEUtils.generateCodeChallenge(codeVerifier);
  final state = PKCEUtils.generateCodeVerifier().substring(0, 16);

  print('\n[Step 1] Generated PKCE Secrets:');
  print('Code Verifier: $codeVerifier');
  print('Code Challenge: $codeChallenge');

  // 2. Construct the Authorization URL for Auth0
  final queryParams = {
    // 'audience': audience ?? 'https://api.coop.no',
    // 'access_token_url': 'https://login.coop.no/oauth/token',
    'client_id': clientId,
    'redirect_uri': redirectUri,
    'response_type': 'code',
    'scope': 'openid profile offline_access email phone address',
    'code_challenge': codeChallenge,
    'code_challenge_method': 'S256',
    'state': state,
  };

  if (audience != null && audience.isNotEmpty) {
    queryParams['audience'] = audience;
  }

  final authUrl = Uri.parse(
    'https://login.coop.no/authorize',
  ).replace(queryParameters: queryParams);

  print('\n[Step 2] Open this URL in your browser to authenticate via Auth0:');
  print('\n$authUrl\n');

  print('After authenticating, your browser will try to open a deep link:');
  print('$redirectUri?code=SOME_CODE_HERE&state=$state\n');

  // 3. Prompt user for the redirected URL or code
  stdout.write(
    '[Step 3] Paste the full $redirectUri URL (or just the code) here: ',
  );
  final input = stdin.readLineSync()?.trim();

  if (input == null || input.isEmpty) {
    print('No input provided. Exiting.');
    return;
  }

  String code = input;

  // Extract code if the user pasted the full URL
  if (input.startsWith('no.coop.members://')) {
    try {
      final uri = Uri.parse(input);
      final extractedCode = uri.queryParameters['code'];
      if (extractedCode != null) {
        code = extractedCode;
        print('\nExtracted code: $code');
      } else {
        print('\nCould not find "code" parameter in the URL. Using raw input.');
      }
    } catch (e) {
      print('\nFailed to parse URL. Using raw input.');
    }
  }

  // 4. Exchange the code for a token at Auth0
  print('\n[Step 4] Exchanging code for Access Token...');

  try {
    final response = await http.post(
      Uri.parse('https://login.coop.no/oauth/token'),
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: {
        'grant_type': 'authorization_code',
        'client_id': clientId,
        'redirect_uri': redirectUri,
        'code': code,
        'code_verifier': codeVerifier,
      },
    );

    print('\nResponse Status: ${response.statusCode}');

    if (response.statusCode == 200) {
      final tokenData = jsonDecode(response.body);
      print('\n[SUCCESS] Token Data Received (Auth0):');
      const JsonEncoder encoder = JsonEncoder.withIndent('  ');
      print(encoder.convert(tokenData));
      // 5. Test fetching UserInfo
      final accessToken = tokenData['access_token'];
      if (accessToken != null) {
        print(
          '\n[Step 5] Fetching UserInfo from https://login.coop.no/userinfo...',
        );

        final userInfoResponse = await http.get(
          Uri.parse('https://login.coop.no/userinfo'),
          headers: {'Authorization': 'Bearer $accessToken'},
        );

        print('\nUserInfo Status: ${userInfoResponse.statusCode}');
        if (userInfoResponse.statusCode == 200) {
          final userData = jsonDecode(userInfoResponse.body);
          print('\n[SUCCESS] User Data:');
          print(encoder.convert(userData));
        } else {
          print('\n[FAILED] UserInfo Error:');
          print(userInfoResponse.body);
        }

        // 6. Test fetching Purchase History
        print('\n[Step 6] Fetching Purchase History (Receipts)...');

        // Note: Assuming api.coop.no as the standard backend gateway.
        // If it fails with 404/DNS, the app might use a different subdomain (e.g., app-api.coop.no)
        final historyResponse = await http.get(
          Uri.parse('https://api.coop.no/user/pay/history/list'),
          headers: {
            'Authorization': 'Bearer $accessToken',
            // Adding common mobile app headers just in case they are required by an API Gateway
            'Accept': 'application/json',
            'x-platform': 'android',
          },
        );

        print('\nPurchase History Status: ${historyResponse.statusCode}');
        if (historyResponse.statusCode == 200) {
          try {
            final historyData = jsonDecode(historyResponse.body);
            print('\n[SUCCESS] Purchase History Data:');
            print(encoder.convert(historyData));
          } catch (e) {
            print('\n[SUCCESS] Purchase History Raw Body:');
            print(historyResponse.body);
          }
        } else {
          print('\n[FAILED] Purchase History Error:');
          print(historyResponse.body);
        }
      }
    } else {
      print('\n[FAILED] Error Response:');
      print(response.body);
    }
  } catch (e) {
    print('\n[FAILED] Network error during token exchange: $e');
  }
}
