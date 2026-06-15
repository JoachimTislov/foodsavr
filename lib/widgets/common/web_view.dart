import 'package:flutter/material.dart';
import 'package:foodsavr/injection.dart';
import 'package:foodsavr/controllers/c_grocery_store_auth.dart';
import 'package:webview_flutter/webview_flutter.dart';

class WebView extends StatefulWidget {
  final String? provider;

  const WebView({super.key, required this.provider});

  @override
  State<WebView> createState() => _WebViewState();
}

class _WebViewState extends State<WebView> {
  late final GroceryStoreAuthController _controller;

  @override
  void initState() {
    super.initState();
    _controller = getIt<GroceryStoreAuthController>();
    _controller.webViewController.loadRequest(
      Uri.parse('https://www.chatgpt.com'),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Auth flow ${widget.provider ?? ''}')),
      body: WebViewWidget(controller: _controller.webViewController),
    );
  }
}
