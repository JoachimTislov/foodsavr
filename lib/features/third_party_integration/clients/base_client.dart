import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:foodsavr/features/third_party_integration/models/m_provider.dart';
import 'package:foodsavr/services/s_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:http/retry.dart';
import 'package:logger/logger.dart';

base class Client {
  final Logger logger;
  final SecureStorage storage;
  final http.Client client = RetryClient(http.Client());
  final String baseUrl;
  final Provider provider;
  final Map<String, String> requestHeaders;

  Client(
    this.logger,
    this.storage, {
    required this.provider,
    this.requestHeaders = const {},
  }) : baseUrl = dotenv.get('${provider.name.toUpperCase()}_API_URL');

  void dispose() {
    client.close();
  }

  Future<Map<String, String>> _getHeadersWithAuthorization() async {
    final accessToken = await storage.read(provider, Key.access_token);
    if (accessToken == null) {
      // TODO: should catch and do nothing...?
      throw "Client for $provider isn't authorized";
    }
    requestHeaders['Authorization'] = accessToken;
    return requestHeaders;
  }

  /// env is the key for value - endpoint
  Future<dynamic> fetch(String env, [String suffix = '']) async {
    final endpoint = dotenv.get(env);
    final response = await client.get(
      Uri.parse('$baseUrl$endpoint$suffix'),
      headers: await _getHeadersWithAuthorization(),
    );
    return jsonDecode(utf8.decode(response.bodyBytes));
  }
}
