import 'package:webview_flutter/webview_flutter.dart';

import '../models/m_grocery_store.dart';

abstract class IGroceryStoreAuthService {
  late WebViewController webViewController;
  Future<void> authorize(GroceryStoreProvider provider);
  Future<void> disconnect(GroceryStoreProvider provider);
  Future<Map<String, dynamic>?> fetchUserProfile(GroceryStoreProvider provider);
  Future<List<GroceryStoreConnection>> getConnections();
  Future<String?> getValidAccessToken(GroceryStoreProvider provider);
}
