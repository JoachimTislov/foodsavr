import 'package:flutter/foundation.dart';
import 'package:foodsavr/features/third_party_integration/models/m_provider.dart';

enum Status { mobile_only, not_configured, connected, authorizing }

class Connection {
  final Provider provider;
  final String? accessToken;
  final String? refreshToken;
  final String? idToken;
  final DateTime? accessTokenExpiration;

  const Connection({
    required this.provider,
    required this.accessToken,
    required this.refreshToken,
    required this.idToken,
    required this.accessTokenExpiration,
  });

  bool get isAvailable => !kIsWeb;

  Status get status {
    if (kIsWeb) return Status.mobile_only;
    if (isConnected) return Status.connected;
    return Status.not_configured;
  }

  bool get isConnected => accessToken != null && refreshToken != null; /*&&;
      // idToken != null &&
      // accessTokenExpiration != null;*/
}
