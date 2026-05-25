// ignore_for_file: avoid_print

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
  print('--- Rema 1000 (Æ) OAuth 2.0 PKCE Flow Test ---');

  const clientId = 'android-251010';
  const redirectUri = 'https://ae-appen.appspot.com/redirect/redirect.html';

  // 1. Generate PKCE Secrets and State
  final codeVerifier = PKCEUtils.generateCodeVerifier();
  final codeChallenge = PKCEUtils.generateCodeChallenge(codeVerifier);
  final state = PKCEUtils.generateCodeVerifier().substring(
    0,
    16,
  ); // Alphanumeric state

  print('\n[Step 1] Generated PKCE Secrets:');
  print('Code Verifier: $codeVerifier');
  print('Code Challenge: $codeChallenge');
  print('State: $state');

  // 2. Construct the Authorization URL
  final authUrl = Uri.parse('https://id.rema.no/authorization').replace(
    queryParameters: {
      'client_id': clientId,
      'redirect_uri': redirectUri,
      'response_type': 'code',
      'scope': 'all',
      'code_challenge': codeChallenge,
      'code_challenge_method': 'S256',
      'state': state,
    },
  );

  print('\n[Step 2] Open this URL in your browser to authenticate:');
  print('\n$authUrl\n');

  print(
    'After authenticating, the ae-appen.appspot.com page will redirect your browser to a deep link.',
  );
  print(
    'Look at the URL in your browser\'s address bar or error message. It will look like this:',
  );
  print('bella://authorize?code=SOME_CODE_HERE&state=$state\n');

  // 3. Prompt user for the redirected URL or code
  stdout.write(
    '[Step 3] Paste the full bella:// URL (or just the code) here: ',
  );
  final input = stdin.readLineSync()?.trim();

  if (input == null || input.isEmpty) {
    print('No input provided. Exiting.');
    return;
  }

  String code = input;

  // Extract code if the user pasted the full URL
  if (input.startsWith('http') || input.startsWith('bella://')) {
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

  // 4. Exchange the code for a token
  print('\n[Step 4] Exchanging code for Access Token...');

  try {
    final response = await http.post(
      Uri.parse('https://id.rema.no/token'),
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
      print('\n[SUCCESS] Token Data Received:');
      const JsonEncoder encoder = JsonEncoder.withIndent('  ');
      print(encoder.convert(tokenData));

      // 5. Try to refresh the token if we received a refresh_token
      final refreshToken = tokenData['refresh_token'];
      if (refreshToken != null) {
        print(
          '\n[Step 5] Attempting to use the refresh_token to get a new access token...',
        );

        final refreshResponse = await http.post(
          Uri.parse('https://id.rema.no/token'),
          headers: {'Content-Type': 'application/x-www-form-urlencoded'},
          body: {
            'grant_type': 'refresh_token',
            'client_id': clientId,
            'refresh_token': refreshToken,
          },
        );

        print('\nRefresh Response Status: ${refreshResponse.statusCode}');
        if (refreshResponse.statusCode == 200) {
          final refreshData = jsonDecode(refreshResponse.body);
          print('\n[SUCCESS] Refreshed Token Data Received:');
          print(encoder.convert(refreshData));
        } else {
          print('\n[FAILED] Failed to refresh token:');
          print(refreshResponse.body);
        }
      } else {
        print(
          '\n[Step 5] No refresh_token was provided in the response, cannot test refresh flow.',
        );
      }

      // 6. Test the actual API by fetching receipts
      final accessToken = tokenData['access_token'];
      if (accessToken != null) {
        print(
          '\n[Step 6] Testing Rema API: Fetching Receipts (Transactions)...',
        );

        // We need a random UUID for correlation and device ID to simulate the app
        final randomUuid =
            '123e4567-e89b-12d3-a456-426614174000'; // Mock UUID for testing

        // Prompt for phone number since the API requires it
        stdout.write(
          'Please enter your phone number (e.g. 47xxxxxxxx) for the x-mobile-nr header: ',
        );
        final phoneInput = stdin.readLineSync()?.trim() ?? '';

        final apiResponse = await http.get(
          Uri.parse('https://api.rema.no/v1/bella/transaction/v2/heads'),
          headers: {
            'Authorization': 'Bearer $accessToken',
            'ocp-apim-subscription-key': 'fb5e24884b504d0bad761098f77e6605',
            'x-platform': 'android',
            'x-correlation-id': randomUuid,
            'x-device-id': randomUuid,
            'x-mobile-nr': phoneInput,
            'x-app': 'bella',
            'x-app-version': '3.0.12 #110549',
          },
        );

        print('\nReceipts API Status: ${apiResponse.statusCode}');

        if (apiResponse.statusCode == 200) {
          try {
            final receiptData = jsonDecode(apiResponse.body);
            print('\n[SUCCESS] Receipts Data Received:');
            print(encoder.convert(receiptData));
          } catch (e) {
            print('\n[SUCCESS] Receipts Raw Body (not JSON):');
            print(apiResponse.body);
          }
        } else {
          print('\n[FAILED] API Error Response:');
          print(apiResponse.body);
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
