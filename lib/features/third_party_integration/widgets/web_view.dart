import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:foodsavr/features/third_party_integration/oauth_controller.dart';
import 'package:foodsavr/features/third_party_integration/models/provider_model.dart';
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
      if (!mounted) return;
      if (_controller.connectionFailed) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('settings.integrations.connectionFailed'.tr()),
          ),
        );
      }
      if (ModalRoute.of(context)?.isCurrent == true && context.canPop()) {
        context.pop();
      }
    });
  }

  @override
  void dispose() {
    _controller.cancelConnection();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          '${'settings.integrations.actions.connecting'.tr()} ${widget.provider}',
        ),
      ),
      body: WebViewWidget(controller: _controller.webview),
    );
  }
}
