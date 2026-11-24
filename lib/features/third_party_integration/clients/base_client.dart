import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:foodsavr/features/third_party_integration/models/provider_model.dart';
import 'package:foodsavr/features/third_party_integration/services/store_credentials.dart';
import 'package:http/http.dart' as http;
import 'package:http/retry.dart';
import 'package:logger/logger.dart';

base class Client {
  final Logger logger;
  final StoreCredentials credentials;
  final http.Client client;
  final String baseUrl;
  final Provider provider;
  final Map<String, String> requestHeaders;

  Client(
    this.logger,
    this.credentials,
    http.Client client, {
    required this.provider,
    this.requestHeaders = const {},
  }) : client = RetryClient(client),
       baseUrl = dotenv.get('${provider.name.toUpperCase()}_API_URL');

  void dispose() {
    client.close();
  }

  Future<http.Response> _get(Uri uri, String accessToken) => client.get(
    uri,
    headers: {...requestHeaders, 'Authorization': accessToken},
  );

  /// env is the key for value - endpoint
  ///
  /// Refreshes the access token once on HTTP 401 and retries; throws
  /// [StoreReconnectRequired] when the store still rejects it.
  Future<dynamic> fetch(String env, [String suffix = '']) async {
    final endpoint = dotenv.get(env);
    final accessToken = await credentials.accessToken(provider);
    if (accessToken == null) return {};
    final uri = Uri.parse('$baseUrl$endpoint$suffix');
    var response = await _get(uri, accessToken);
    if (response.statusCode == 401) {
      final refreshed = await credentials.refresh(
        provider,
        rejected: accessToken,
      );
      response = await _get(uri, refreshed);
      if (response.statusCode == 401) throw const StoreReconnectRequired();
    }
    return jsonDecode(utf8.decode(response.bodyBytes));
  }
}
