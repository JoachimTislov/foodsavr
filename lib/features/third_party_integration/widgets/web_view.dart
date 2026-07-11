import 'package:flutter/material.dart';
import 'package:foodsavr/features/third_party_integration/oauth_controller.dart';
import 'package:foodsavr/features/third_party_integration/models/m_provider.dart';
import 'package:foodsavr/injection.dart';
import 'package:go_router/go_router.dart';
import 'package:webview_flutter/webview_flutter.dart';

class WebView extends StatefulWidget {
  final Provider provider;

  WebView({super.key, String? provider})
    : provider = Provider.values.byName(provider!);

  @override
  State<WebView> createState() => _WebViewState();
}

class _WebViewState extends State<WebView> {
  final OAuthController _controller = getIt<OAuthController>();

  @override
  void initState() {
    super.initState();
    _controller.connect(widget.provider).whenComplete(() {
      if (mounted && context.canPop()) {
        context.pop();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.provider.toString())),
      body: WebViewWidget(controller: _controller.webview),
    );
  }
}
