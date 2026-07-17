import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:foodsavr/features/third_party_integration/models/provider_model.dart';
import 'package:foodsavr/services/secure_storage_service.dart';
import 'package:http/http.dart' as http;
import 'package:http/retry.dart';
import 'package:logger/logger.dart';

base class Client {
  final Logger logger;
  final SecureStorage storage;
  final http.Client client;
  final String baseUrl;
  final Provider provider;
  final Map<String, String> requestHeaders;

  Client(
    this.logger,
    this.storage,
    http.Client client, {
    required this.provider,
    this.requestHeaders = const {},
  }) : client = RetryClient(client),
       baseUrl = dotenv.get('${provider.name.toUpperCase()}_API_URL');

  void dispose() {
    client.close();
  }

  Future<(Map<String, String>, bool)> _getHeadersWithAuthorization() async {
    final accessToken = await storage.read(provider, Key.access_token);
    if (accessToken == null) {
      return (requestHeaders, false);
    }
    requestHeaders['Authorization'] = accessToken;
    return (requestHeaders, true);
  }

  /// env is the key for value - endpoint
  Future<dynamic> fetch(String env, [String suffix = '']) async {
    final endpoint = dotenv.get(env);
    final (headers, authorized) = await _getHeadersWithAuthorization();
    if (!authorized) return {};
    final response = await client.get(
      Uri.parse('$baseUrl$endpoint$suffix'),
      headers: headers,
    );
    return jsonDecode(utf8.decode(response.bodyBytes));
  }
}
