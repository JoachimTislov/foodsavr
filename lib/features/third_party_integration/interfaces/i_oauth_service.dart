import 'package:foodsavr/features/third_party_integration/models/connection_model.dart';
import 'package:foodsavr/features/third_party_integration/models/provider_model.dart';
import 'package:webview_flutter/webview_flutter.dart';

abstract class IOAuthService {
  Future<void> authorize(Provider provider);
  Future<List<Connection>> getConnections();
  Future<Map<String, dynamic>?> fetchUserProfile(Provider provider);
  WebViewController get webViewController;
}
