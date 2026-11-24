// The platform interface provides the WebView test seam.
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart'; // ignore: depend_on_referenced_packages

/// Marks a native WebView as available without creating one.
class FakeWebViewPlatform extends WebViewPlatform {}
