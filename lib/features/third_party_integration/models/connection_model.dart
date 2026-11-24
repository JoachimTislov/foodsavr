import 'package:flutter/foundation.dart';
import 'package:foodsavr/features/third_party_integration/models/provider_model.dart';

enum Status {
  mobile_only,
  not_configured,
  connected,
  authorizing,

  /// The store rejected the grant; the user has to reconnect.
  reconnect_required,

  /// Connected, but the store could not be reached to renew access.
  unavailable,
}

/// Why a connection cannot be used right now.
enum ConnectionIssue { reconnectRequired, temporarilyUnavailable }

class Connection {
  final Provider provider;
  final String? accessToken;
  final String? refreshToken;
  final String? idToken;
  final DateTime? accessTokenExpiration;
  final ConnectionIssue? issue;

  const Connection({
    required this.provider,
    required this.accessToken,
    required this.refreshToken,
    required this.idToken,
    required this.accessTokenExpiration,
    this.issue,
  });

  bool get isAvailable => !kIsWeb;

  Status get status {
    if (kIsWeb) return Status.mobile_only;
    if (issue == ConnectionIssue.reconnectRequired) {
      return Status.reconnect_required;
    }
    if (isConnected) {
      return issue == ConnectionIssue.temporarilyUnavailable
          ? Status.unavailable
          : Status.connected;
    }
    return Status.not_configured;
  }

  bool get isConnected => accessToken != null && refreshToken != null;
}
