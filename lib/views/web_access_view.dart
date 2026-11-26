import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../services/web_access.dart';
import '../widgets/auth/public_page_links.dart';

class WebAccessView extends StatefulWidget {
  const WebAccessView({super.key, required this.access});

  final WebAccess access;

  @override
  State<WebAccessView> createState() => _WebAccessViewState();
}

class _WebAccessViewState extends State<WebAccessView> {
  final _code = TextEditingController();
  bool _invalid = false;

  void _submit() {
    if (!widget.access.unlock(_code.text)) {
      setState(() => _invalid = true);
    }
  }

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'FoodSavr', // l10n-ignore
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _code,
                  obscureText: true,
                  onSubmitted: (_) => _submit(),
                  decoration: InputDecoration(
                    labelText: 'webAccess.code'.tr(),
                    errorText: _invalid ? 'webAccess.invalid'.tr() : null,
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _submit,
                  child: Text('webAccess.continue'.tr()),
                ),
                const PublicPageLinks(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
